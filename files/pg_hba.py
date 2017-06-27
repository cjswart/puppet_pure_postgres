#!/usr/bin/python

'''
# Copyright (C) 2017 Collaboration of KPN and Splendid Data
#
# This file is part of puppet_pure_postgres.
#
# puppet_pure_barman is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# puppet_pure_postgres is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with puppet_pure_postgres.  If not, see <http://www.gnu.org/licenses/>.
'''

'''
This script is used to manage pg_hba rules in a pg_hba.conf file.
It reads the rules, checks if a change should be made, and applies if it does.
It can handle both ipv4 addresses/networks aswell as ipv6 addresses/networks.

A strong point is that it manages rules very intelligently.
- It converts IP addresses to integers and as such it will see no difference between 
  - 192.168.0.1 and 192.168.0.01
  - ::c0a8::1 and ::192.168.0.1
- It converts a base (e.a. /24) to a netmask (e.a. 255.255.255.0) and uses that as 
  part of the key to register the rule in the local object. Therefore it sees both 
  as the same (192.168.0.1/24 is the same source as 192.168.0.1/255.255.255.0 )
- It sorts rules from fine grained to large grained. This makes it possble to
  - Create a rule excluding everyting from segment 192.168.0.1/24
  - After that create a rule to grant access to 192.168.0.100
- It removes duplicates

A weak point is that it always re-sorts the rules.
So manually managed hba files (which have a different sort, applied by hand),
might change after using this script and this could have technical implications.
This is not a big concern as long as you use only this script to manage, 
only if you use this with manually managed files.

Example usage:
The following command:
  pg_hba.py -b -c -d postgres,test1 -f /tmp/pg_hba.conf -g dba --mode 640 -n 255.255.255.0 --owner postgres -o sdu --state present -r -s 192.168.0.0 -t host -u testuser1,testuser2
Will do the following:
- Create a file /tmp/pg_hba.conf (if it doesn't exist), with owner postgres:dba and mode 640
- Open the file /tmp/pg_hba.conf
- Check if rules below exists, if they all exist: end
- If it doesnt exist add the rule
- sort the file correctly (first by source, then by database, then by user)
- Create a backup file (to a file at /tmp/pg_hba..., exact path printed to stdout) and copy contents to it
- Write the newly generated file back
- reload postgres service (/etc/init.d/postgres reload)
Rules:
  host	postgres	testuser1	192.168.0.0	255.255.255.0	md5
  host	test1	testuser1	192.168.0.0	255.255.255.0	md5
  host	test1	testuser2	192.168.0.0	255.255.255.0	md5
  host	postgres	testuser2	192.168.0.0	255.255.255.0	md5

Last but not least: the -o option. The script tries to correctly sort the rules based on the grainness. So:
- a /24 network will enter below a /32 network (single ip) and above a /16 network.
- a user will enter above keyword all
- a database will enter above keyword all
But, what would happen if two rules have seperate garins per dimension. 
For instance, a rule for a /24 segment for a particular user, and a rule for a /32 network for keyword all (for all users).
In that case, the -o option will set which part has priority over the other. 
- sdu will choose source over database over users, so
  The rule for a /24 segment for a particular user will end below the rule for a /32 network for all users.
- usd will choose user over source over database, so
  The rule for a /32 network for all users will end below the rule for a /24 segment for a particular user.
'''

import os
import pwd
import grp
import stat
import re
import tempfile
import shutil
import subprocess
import sys

'''
This exception is raised when the touch function fails.
'''
class TouchError(Exception):
    pass

'''
This function creates an empty file with proper ownership and permissions if it doesn't already exist.
'''
def touch(path, owner, group, mode):
    try:
        #If it exists, then exit this function
        fstat = os.stat(path)
        return
    except:
        pass
    try:
        #create a file by opening and closing it
        f=open(path, 'w')
        f.close()
        fstat = os.stat(path)
    except:
        raise TouchError('Could not create file {0}. Please become a user with sufficient permissions.'.format(path))
    try:
        #get user info, like uid
        usr = pwd.getpwnam(owner)
    except:
        raise TouchError('User {0} is unknown on this system. Please specify a valid owner for the file.'.format(owner))
    try:
        #get group info like gid
        group = grp.getgrnam(group)
    except:
        raise TouchError('Group {0} is unknown on this system. Please specify a valid owner for the file.'.format(group))
    try:
        #convert octal string to integer
        #Example: 644 would become 420 (6*64 + 4*8 + 4)
        mode=int(str(mode),8)
    except:
        raise TouchError("Could not convert '{0}' form octal to int. Please specify a valid mode in octal form (e.a. 777, 640, etc.).".format(mode))
    if mode > 511 or mode < 0:
        raise TouchError("Please specify octal mode between 000 and 777.".format(mode))
    try:
        if stat.S_IMODE(fstat.st_mode) != mode:
            #filemode not as it should. changing.
            os.chmod(path, mode)
        if fstat.st_uid != usr.pw_uid or fstat.st_gid != group.gr_gid:
            #file ownership not as it should. changing.
            os.chown(path, usr.pw_uid, group.gr_gid)
    except:
        raise TouchError("Could not set owner, group or permissions on file. Please become a user with sufficient permissions.".format(mode))


'''
This exception is raised when issues occur with ip calculations .
'''
class IPError(Exception):
    pass

'''
This function converts a string containing an ip address like '192.168.0.101' to an integer like 3232235621.
It is the inverse of int_to_ipv4().
'''
def ipv4_to_int(ip):
    if type(ip) is int:
        # If IP was already an integer, then just return it unchanged
        return ip
    elif type(ip) is str:
        #Split by '.'
        ip_ar = ip.split(".")
        #check that there are 4 parts
        if len(ip_ar) != 4:
            raise IPError("Invalid IP: {0}. We need 4 numbers in an IP".format(ip))
        #Start empty
        ip=0
        #Loop through parts and
        for i in ip_ar:
            try:
                #convert to int
                i=int(i)
            except:
                raise IPError("IP part {0} must be numeric".format(i))
            #Check that it is within range
            if i<0 or i>255:
                raise IPError("IP part {0} must be from 0-255".format(i))
            #Scale original part up 256 times and add the new part
            ip=ip*256+i
        #IP p1.p2.p3.p4 should now be 256**3 * p1 + 256**2 * p2 + 256 * p3 + p4.
        #Return as result
        return ip
    else:
        raise IPError("{0} has an invalid type for an IP.".format(ip.__repr__()))

'''
This function converts an integer converted ip address like 3232235621 back into a string like '192.168.0.101'.
It is the inverse of ipv4_to_int().
'''
def int_to_ipv4(i):
    try:
        # Check that it is (or can be convert to) a basic integer
        i = int(i)
    except:
        raise IPError("{0} is not an integer.".format(i.__repr__()))
    if i >= 2**32 or i < 0:
        raise IPError('IP address number out of range.')
    ip = []
    for x in range(4):
        #First see what the scale factor (what we should divide i by to get the part) of this part is.
        #For part 0 (everything that should end up before the first dot) it would be 256**3
        #For part 3 (everything that should end up after the last dot) it would be 1
        scale = 256**(3-x)

        #Then divide i by scale and trim everything larger than 256 and everything smaller than 1
        part=int(i/scale) % 256

        #Convert part to string and add to list
        ip.append(str(part))

    #By now, we have a list of parts like ['192', '168', '0', '101' ].
    #Join the list elements to one string, seperated by dot and you get the reult, like '192.168.0.101'.
    return '.'.join(ip)

'''
This function converts a string containing a network base like '/24' to a netmask like '256.256.256.0'.
'''
def prefix_to_ipv4netmask(base):
    if type(base) is str:
        #It could contain a /. If it does, remove it.
        base=base.replace('/','')
    try:
        #convert to int
        base=int(base)
    except:
        raise IPError("invalid numeric expression for ipv4 network base {}".format(base))

    #Generate the amount of ones as required (/24 would generate 16 times a 1, like 111111111111111111111111)
    #Basically, 2**24 would be a 1 and 24 zeros. If you substract 1, you end up with 24 1's.
    ones = 2**base-1

    #After the ones, there should be a number of zeroes making a total of 32 bits.
    #So for 24 1's there should be 8 zero's and for 16 there should be 16. This is always (32-base) zero's.
    #For every zero, one could multiply by two, so for 8 zero's one should multiply by 2**8.
    #And for (32-base) zero's, one can multiply with 2**(32-base)
    multiplier = 2 ** (32-base)
    netmask = ones * multiplier

    #convert t to a ipv4 string with int_to_ipv4 and return it
    return int_to_ipv4(netmask)

'''
This function converts a string containing an ipv6 address like 'fe80::79ee:7b70:320f:8877' 
into an integer like 338288524927261089662804992486200543351.
It understands (and converts) an ipv4 part in a ipv6 address, aswell as '::'
It is the inverse of int_to_ipv6() and the ipv6 alternate to ipv4_to_int().
'''
def ipv6_to_int(ip):
    # We will create a normalized version too.
    # Better copy to new varaiable and leave the passed in unchanged,
    # so that it is easy to compare during debug
    normalized = ip
    if '.' in normalized:
        # If it holds a '.', it probably holds an ipv4 part.
        # Check using re.search
        m = ipv4part_re.search(normalized)
        #Convert ipv4 parts (dec) to ipv6 parts (hex)
        ipv6part = ''.join('%02x'%int(i) for i in m.group(0).split('.'))
        #It is now one hex of 8 digits, while it should be two of 4. Lets insert a ':' in the middle.
        ipv6part = ipv6part[:4] + ':' + ipv6part[4:]
        #And replace the ipv4 part in the ip by the just generated ipv6 counterpart
        normalized = normalized.replace(m.group(0), ipv6part)
    if '::' in ip:
        if ':::' in ip:
            raise IPError('::: is not valid in ipv6')
        # It is possible that multiple parts of ':0000:' are together replaced by a single '::'.
        # If so, we should rstore that to the ':0000:' parts
        # First see how much are missing
        missing = 8 - normalized.count(':')
        # This creates a string with '0000' elements surrounded and seperated by ':', just as much as there where missing.
        replacer = ':'+'0000:'*missing
        # Replace the '::' by the replacer string
        normalized = normalized.replace('::', replacer)
        #If :: was at the beginning (or the end), the initial (or last) ':' should not be there...
        normalized.strip(':')
        #normalized = normalized.replace('::',':')
    #Now split in multiple parts
    parts = normalized.split(':')
    if len(parts) < 8:
        raise IPError('IPv6 seems to consist of too less parts')
    elif len(parts) > 8:
        raise IPError('IPv6 seems to consist of too much parts')
    #Normalize: Every part should have 4 digits. If not, the join would produce the correct number.
    for i in range(len(parts)):
        if len(parts[i]) != 4:
            part = '0000' + parts[i]
            part = part[-4:]
            parts[i] = part
    #Since it is now normalized, we can glue all together and handle this as one huge hexadecimal number
    hex_result = ''.join(parts)
    #convert to int with base 16 and return the result
    return int(hex_result,16)

'''
This function converts an integer converted ip address like 338288524927261089662804992486200543351 
back into a string containing an ipv6 address like 'fe80::79ee:7b70:320f:8877'.
It cleans up by leading zeros and replacing multiple instances of ':0:' by '::'.
It is the inverse of ipv6_to_int() and the ipv6 counterpart of ipv6_to_int.
'''
def int_to_ipv6(i):
    try:
        i = int(i)
    except:
        raise IPError("{0} is not an integer.".format(i.__repr__()))
    #convert to hex, but remove the 0x front
    hex_i = hex(i).split('x')[-1]
    #Add '0' to the front up until 32 characters total
    hex_i = '0'*(32 - len(hex_i)) + hex_i
    #split in parts of 4 characters
    parts = [ hex_i[i:i+4] for i in range(0, 32, 4) ]
    #Lets loop through the parts and clean those leading zero's
    for n in range(len(parts)):
        #Not looping though parts directly, but using n, so we now the index and can later replace more easilly.
        #But get the part in seperate variable for easier access
        part = parts[n]
        #look for leading zero
        while part[0] == '0' and part != '0':
            #remove leading zero
            part = part[1:]
        #write back to parts list
        parts[n] = part
    #join seperated with ':'. It now looks like a valid ipv6, but some cleanup can be done.
    ipv6 = ':'.join(parts)
    #Find repetions of zero fields to replace by '::'
    obsoletes = [ m.group(0) for m in ipv6_obs_re.finditer(ipv6) ]
    if len(obsoletes) > 0:
        # Find largest number of repetitions
        obsoletes = sorted(obsoletes, key=len)
        largest_obsolete = obsoletes[-1]
        # Replace only the first occurrence of this repetition by '::'
        ipv6 = ipv6.replace(largest_obsolete, '::', 1)
    if ipv6.startswith('0::'):
        # If it starts with '0::', the '0' should be left out too.
        ipv6 = ipv6[1:]
    if ipv6.endswith('::0'):
        # If it ends with '::0', the '0' should be left out too.
        ipv6 = ipv6[:-1]
    #This is clean ipv6, Lets return.
    return ipv6

def prefix_to_ipv6netmask(base):
    if type(base) is str:
        #if it is a string, could be that a '/' is still in it. remove it if so.
        base=base.replace('/','')
    try:
        #convert to integer
        base=int(base)
    except:
        raise IPError("invalid numeric expression for ipv6 network base {}".format(base))

    #Generate the amount of ones as required (/24 would generate 16 times a 1, like 111111111111111111111111)
    #Basically, 2**24 would be a 1 and 24 zeros. If you substract 1, you end up with 24 1's.
    ones = 2**base-1

    #After the ones, there should be a number of zeroes making a total of 128 bits.
    #So for 96 1's there should be 32 zero's and for 64 there should be 64. This is always (128-base) zero's.
    #For every zero, one could multiply by two, so for 32 zero's one should multiply by 2**32.
    #And for (128-base) zero's, one can multiply with 2**(128-base)
    multiplier = 2 ** (128-base)
    netmask = ones * multiplier

    #convert t to a ipv6 string with int_to_ipv6 and return it
    return int_to_ipv6(netmask)

def gateway(network, netmask):
    if ipv4_re.search(network):
        nw_int = ipv4_to_int(network)
        nm_int = ipv4_to_int(netmask)
        return (nw_int & nm_int) + 1
    elif ipv6_re.search(network):
        nw_int = ipv6_to_int(network)
        nm_int = ipv6_to_int(netmask)
        return (nw_int & nm_int) + 1
    else:
        return 0

'''
The following generates a regular expression which can be used to find ipv4 addresses.
There are easier approaches, but this is the most thorough one.
See http://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses for more info...
'''
#segment of ipv4, can be 0 to 255
IPV4SEG   = '(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])'
#IPv4 address consists of 3x(segment+.)+segement
IPV4ADDR  = '('+IPV4SEG+'\.){3,3}'+IPV4SEG

'''
The following generates a regular expression which can be used to find ipv6 addresses.
There are easier approaches, but this is the most thorough one.
See http://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses for more info...
'''

#segment of ipv6, can be 0 to 4 times (0-9, a-z or A-Z)
IPV6SEG   = '[0-9a-fA-F]{1,4}'

#This a concattenation of all possible combinations that would describe a valid ipv6 address.
#Comment after the line gives an example.
IPV6ADDR  = '(('+IPV6SEG+':){7,7}'+IPV6SEG+'|'           # 1:2:3:4:5:6:7:8
IPV6ADDR += '('+IPV6SEG+':){1,7}:|'                      # 1::
IPV6ADDR += '('+IPV6SEG+':){1,6}:'+IPV6SEG+'|'           # 1::8               1:2:3:4:5:6::8   1:2:3:4:5:6::8
IPV6ADDR += '('+IPV6SEG+':){1,5}(:'+IPV6SEG+'){1,2}|'    # 1::7:8             1:2:3:4:5::7:8   1:2:3:4:5::8
IPV6ADDR += '('+IPV6SEG+':){1,4}(:'+IPV6SEG+'){1,3}|'    # 1::6:7:8           1:2:3:4::6:7:8   1:2:3:4::8
IPV6ADDR += '('+IPV6SEG+':){1,3}(:'+IPV6SEG+'){1,4}|'    # 1::5:6:7:8         1:2:3::5:6:7:8   1:2:3::8
IPV6ADDR += '('+IPV6SEG+':){1,2}(:'+IPV6SEG+'){1,5}|'    # 1::4:5:6:7:8       1:2::4:5:6:7:8   1:2::8
IPV6ADDR += IPV6SEG+':((:'+IPV6SEG+'){1,6})|'            # 1::3:4:5:6:7:8     1::3:4:5:6:7:8   1::8
IPV6ADDR += ':((:'+IPV6SEG+'){1,7}|:)|'                  # ::2:3:4:5:6:7:8    ::2:3:4:5:6:7:8  ::8       ::       
IPV6ADDR += 'fe80:(:'+IPV6SEG+'){0,4}%[0-9a-zA-Z]{1,}|'  # fe80::7:8%eth0     fe80::7:8%1  (link-local IPv6 addresses with zone index)
IPV6ADDR += '::(ffff(:0{1,4}){0,1}:){0,1}'+IPV4ADDR+'|'  # ::255.255.255.255  ::ffff:255.255.255.255  ::ffff:0:255.255.255.255 (IPv4-mapped IPv6 addresses and IPv4-translated addresses)
IPV6ADDR += '('+IPV6SEG+':){1,4}:'+IPV4ADDR+')'          # 2001:db8:3:4::192.0.2.33  64:ff9b::192.0.2.33 (IPv4-Embedded IPv6 Address)

#regular expression to detect if a string is an ipv4 address
ipv4_re     = re.compile('^\s*'+IPV4ADDR+'(/\d{1,2})?\s*$')
#regular expression to find an ipv4 address in a string
ipv4part_re = re.compile(IPV4ADDR)
#regular expression to detect if a string is an ipv6 address
ipv6_re     = re.compile('^\s*'+IPV6ADDR+'(/\d{1,3})?\s*$')
#regular expression to find an ipv6 address in a string
ipv6_obs_re = re.compile('(\s|:)(0{1,4}:)+')

'''
These are some lists that act as enum for the valid values for pg_hba settings.
'''
# This is a list of authentication methods that can be set in pg_hba
PgHbaMethods = [ "trust", "reject", "md5", "password", "gss", "sspi", "krb5", "ident", "peer", "ldap", "radius", "cert", "pam" ]
# This is a list of source types that can be set in pg_hba
PgHbaTypes = [ "local", "host", "hostssl", "hostnossl" ]
# This is a list of abbreviations that can be set to control the order of lines
PgHbaOrders = [ "sdu", "sud", "dsu", "dus", "usd", "uds"]
# This is a list of headers that the elements of pg_hba have
PgHbaHDR = [ 'type', 'db', 'usr', 'src', 'mask', 'method', 'options']

#Always split by any of spaces, tabs and \n
split_re = re.compile('\s+')

'''
This exception is raised by the PgHba object when an issue arises
'''
class PgHbaError(Exception):
    pass

'''
This class is used to read and process a pg_hba file.
'''
class PgHba(object):
    def __init__(self, pg_hba_file=None, order="sdu", backup=False):
        '''
        Initialize a pg_hba object.
        - pg_hba_file should be the path of a pg_hba file.
        - order should be a string of three characters 's', 'd', and 'u'. Every character exactly once.
        - backup should be set to true to keep a backup of the original file, or to false not to keep a backup.
        '''

        #Check that order is one of "sdu", "sud", "dsu", "dus", "usd", "uds"
        if order not in PgHbaOrders:
            raise PgHbaError("invalid order setting {0} (should be one of '{1}').".format(order, "', '".join(PgHbaOrders)))
        #Copy parameters to new object
        self.pg_hba_file = pg_hba_file
        self.rules      = None
        self.comment    = None
        self.changed    = True
        self.order      = order
        self.backup     = backup

        #Read the rules of the hba file
        self.read()

    def read(self):
        '''
        This procedure read the rules from the pg_hba file.
        '''

        #Reset self.rules and self.comment
        self.rules = {}
        self.comment = []

        if not self.pg_hba_file:
           return

        try:
            # open the pg_hbafile
            f = open(self.pg_hba_file, 'r')
            #Process al lines
            for l in f:
                #Strip spaces
                l=l.strip()
                #uncomment
                if '#' in l:
                    l, comment = l.split('#', 1)
                    self.comment.append('#'+comment)
                #Convert line to rule
                rule = self.line_to_rule(l)
                if rule:
                    #Add rule to this object
                    self.add_rule(rule)
            # Finished reading all lines. Done with this file.
            f.close()
            # Since we have read contents, this object represents file without changes, so write should do anything.
            self.changed = False
        except IOError, e:
            raise PgHbaError("pg_hba file '{0}' doesn't exist. Use create option to autocreate.".format(self.pg_hba_file))

    def line_to_rule(self, line):
        #First we check that the line actually has info (next to only seperator characters like space and tab).
        #This is checked by replacing all seperator characters with ''. If there is anything left in result, there is data in there.
        if split_re.sub('', line) == '':
            #empty line. skip this one...
            return None
        #Now split with split_re in cols
        cols = split_re.split(line)
        #And check that the number of cols is as it is expected
        if len(cols) < 4:
            raise PgHbaError("File {0} has a rule with too few columns: {1}.".format(self.pg_hba_file, line))
        if cols[0] not in PgHbaTypes:
            raise PgHbaError("File {0} contains an rule of unknown type: {1}.".format(self.pg_hba_file, line))
        if cols[0] == 'local':
            if cols[3] not in PgHbaMethods:
                raise PgHbaError("File {0} contains an rule of 'local' type where 4th column '{1}'isnt a valid auth-method.".format(self.pg_hba_file, cols[3]))
            #For local type, the cols address and netmask are not set in hba file. Set them to none
            cols.insert(3, None)
            cols.insert(3, None)
        else:
            if len(cols) < 6:
                #For host type, the cols address and netmask are not set in hba file. Set them to none
                cols.insert(4, None)
            elif cols[5] not in PgHbaMethods:
                #Unknown method. Probably this is no method.
                cols.insert(4, None)
            if len(cols) < 7:
                #options are not set (which is almost always). Set to none
                cols.insert(7, None)
            if cols[5] not in PgHbaMethods:
                raise PgHbaError("File {0} contains an rule '{1}' that has no valid method.".format(self.pg_hba_file, line))
        #Convert list to dict with named items
        rule = dict(zip(PgHbaHDR, cols[:7]))
        #Remove all columns that have no value from dictionary
        self.cleanEmptyRuleKeys(rule)
        #Set original line in the line value (for future reference)
        rule['line'] = line
        return rule

    def cleanEmptyRuleKeys(self, rule):
        '''
        This function is a helper function that cleans out dictionary keys 
        that have no value (value that evaluates to False, like '', False, -1, etc).
        '''
        for k in rule.keys():
            if not rule[k]:
                del rule[k]

    def rule2key(self, rule):
        '''
        This function generates a key from a rule. The key consists of source, db and usr.
        '''
        #Set source to something udefull
        if rule['type'] == 'local':
            #For local conenctions, source can be local
            source = 'local'
        elif ipv4_re.search(rule['src']):
            #Handle as ipv4 source
            if '/' in rule['src']:
                #Network inidicated as base. Convert to netmask notation.
                nw, prefix = rule['src'].split('/')
                netmask = prefix_to_ipv4netmask(prefix)
                source = nw+'/'+netmask
            elif 'mask' not in rule.keys():
                #Network not inidicated. set to 255.255.255.255 (equivalent of /32 which is one ip).
                source = rule['src']+'/255.255.255.255'
            else:
                #Network inidicated as ip with netmask. Glue ip and netmask togethers with slash.
                source = rule['src']+'/'+rule['mask']
        elif ipv6_re.search(rule['src']):
            #Handle as ipv6 source
            if '/' in rule['src']:
                #Network inidicated as base. Convert to netmask notation.
                nw, prefix = rule['src'].split('/')
                netmask = prefix_to_ipv6netmask(prefix)
                source = nw+'/'+netmask
            elif 'mask' not in rule.keys():
                #Network not inidicated. set to ffff:ffff:ffff:ffff:ffff:ffff (equivalent of /128, which is one ip).
                source = rule['src']+'/ffff:ffff:ffff:ffff:ffff:ffff'
            else:
                #Network inidicated as ip with netmask. Glue ip and netmask togethers with slash.
                source = rule['src']+'/'+rule['mask']
        else:
            #Don't understand, lets not be smart.
            source = rule['src']

        return (source, rule['db'], rule['usr'])

    def rule2weight(self, rule):
        '''
        This function can calculate the weight from a rule.
        It is only used during the render function, which sorts and outputs the rules in correct order.

        The weigth actually defines the grainness of the rule (how specific is this rule).
        For networks, every 1 in 'netmask in binary' makes the subnet more specific.
        Therefore network prefix has an important imact on the weight.
        So a single IP (/32) should have twice the weight of a /16 network.
        To keep everything in the same weight scale for IPv6,
        - a scale of 0 - 128 from 0 bits to 32 bits is chosen for ipv4 and 
        - a scale of 0 - 128 from 0 bits to 128 bits is chosen for ipv6.
        In addition to weight, also the db, username and the gateway is added to sort on that too.
        '''
        if rule['type'] == 'local':
            #local is always 'this server' and therefore considered /32
            srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
            gw = 0
        elif ipv4_re.search(rule['src']):
            if '/' in rule['src']:
                #prefix tells how much 1's there are in netmask, so lets use that for sourceweight
                ip, prefix = rule['src'].split('/', 1)
                srcweight = int(prefix) * 4
                gw = gateway(ip, prefix_to_ipv4netmask(prefix))
            elif 'mask' in rule.keys():
                #Netmask. But /24 = the number of 1's in the binary form of the netmask,
                #So let's count the 1's in this netmask in binary form and use that for weight.
                bits = "{0:b}".format(ipv4_to_int(rule['mask']))
                srcweight = bits.count('1') * 4
                gw = gateway(rule['src'], rule['mask'])
            else:
                #seems, there is no netmask / prefix to be found. Then only one IP applies.
                #ipv4 /32 is considered equivalent to ipv6 /128.
                srcweight = 128
                gw = ip4_to_int(rule['src'])
        elif ipv6_re.search(rule['src']):
            if '/' in rule['src']:
                #prefix tells how much 1's there are in netmask, so lets use that for sourceweight
                ip, prefix = rule['src'].split('/', 1)
                srcweight = int(prefix)
                gw = gateway(ip, prefix_to_ipv6netmask(prefix))
            elif 'mask' in rule.keys():
                #Netmask. But /24 = the number of 1's in the binary form of the netmask,
                #So let's count the 1's in this netmask in binary form and use that for weight.
                bits = "{0:b}".format(ipv6_to_int(rule['mask']))
                srcweight = bits.count('1') * 4
                gw = gateway(rule['src'], rule['mask'])
            else:
                #seems, there is no netmask / prefix to be found. Then only one IP applies.
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
                gw = ip6_to_int(rule['src'])
        else:
            #You can also write all to match any IP address, samehost to match any of the server's own IP addresses, or samenet to match any address in any subnet that the server is directly connected to.
            if rule['src'] == 'all':
                #every ip is ok. Lets put this one on the very bottom of the file.
                srcweight = 0
                gw = 1
            elif rule['src'] == 'samehost':
                #All i's from this host is ok. Lets consider this is only one ip.
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
                gw = 0
            elif rule['src'] == 'samenet':
                #Might write some fancy code to determine all prefix's 
                #from all interfaces and find a sane value for this one.
                #For now, let's assume /24...
                srcweight = 96 #(ipv4 /24 is considered equivalent to ipv6 /96)
                gw = 0
            elif rule['src'][0] == '.':
                # suffix matching, let's asume a very large scale and therefore a very low weight.
                srcweight = 64 #(ipv4 /16 is considered equivalent to ipv6 /64)
                gw = -1
            else:
                #This seems to be a hostname. Let's asume only one host matches
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
                gw = -1

        #dbweight is equal to the number of databases.
        if rule['db'] == 'all':
            #More than one, make it huge and sink to the bottom.
            dbweight = 1000
        else:
            #Count comma's to find number of databases
            dbweight = rule['db'].count(',') + 1

        #uweight is equal to the number of users

        if rule['usr'] == 'all':
            #All users, so (probably) more than one. Sink to bottom.
            uweight = 1000
        else:
            #More than one, sink to the bottom
            uweight = rule['usr'].count(',') + 1

        #Now, put the weights in the correct order, according to self.order parameter
        ret = []
        for c in self.order:
            if c == 'u':
                ret.append(uweight)
            elif c == 's':
                ret.append(-srcweight)
            elif c == 'd':
                ret.append(dbweight)
        #Add dbname, username and gateway for sort when all else is the same
        ret += [ rule['db'], rule['usr'], gw ]

        #Return the end weight tuple
        return tuple( ret )

    def write(self, reload=False):
        '''
        This function writes a hba file if it has added or deleted rules.
        '''
        if not self.changed:
            #No changes, then don't write either.
            return

        if self.pg_hba_file:
            if self.backup:
                #Filepath is set and backup is selected.
                #Make temp file for backup
                backup_file_h, backup_file = tempfile.mkstemp(prefix='pg_hba')
                #Copy contents
                shutil.copy(self.pg_hba_file, backup_file)
                #Print location of temp file
                print('Backup written to {0}'.format(backup_file))
            #Open the file, so we can write new conent to it
            fileh = open(self.pg_hba_file, 'w')
        else:
            #no file path was set. create temp file
            filed, path = tempfile.mkstemp(prefix='pg_hba')
            #open temp file
            fileh = os.fdopen(filed, 'w')
            #Print location of temp file
            print('Writing changed data to {0}'.format(path))

        #render altered contents and write to file
        for line in self.render():
            fileh.write(line+'\n')
        if reload:
            try:
                #File has changed. reload and don't mind errors if they occur.
                subprocess.call(['/etc/init.d/postgres', 'reload'])
            except:
                pass
        #file was written, so file and object are in sync
        self.changed = False
        #Close file (don't need it anymore)
        fileh.close()

    def new_rules(self, contype, databases, users, source, netmask, method, options):
        '''
        This function creates a new rule that fits to the parsed parameters.
        '''

        #Check validity of method and contype parameters
        if method not in PgHbaMethods:
            raise PgHbaError("invalid method {0} (should be one of '{1}').".format(method, "', '".join(PgHbaMethods)))
        if contype not in PgHbaTypes:
            raise PgHbaError("invalid connection type {0} (should be one of '{1}').".format(contype, "', '".join(PgHbaTypes)))

        #Loop through databases (if option was like db1,db2,db3 )
        #and create a new rule for every database
        for db in databases.split(','):
            #Loop through users (if option was like user1,user2,user3 )
            #and create a new rule for every user
            for usr in users.split(','):
                #Create a dictionary contaning the specified rule config
                rule = dict(zip(PgHbaHDR, [contype, db, usr, source, netmask, method, options]))

                #Cleanup some weird combinations
                if contype == 'local':
                    del rule['src']
                    del rule['mask']
                elif '/' in source:
                    del rule['mask']
                elif ipv4_re.search(source):
                    if not netmask:
                        rule['src'] += '/32'
                elif '/' in source:
                    if not netmask:
                        rule['src'] += '/128'
                else:
                    del rule['mask']
                #Cleanup keys with empty values
                self.cleanEmptyRuleKeys(rule)

                #Generate a line that conforms to this rule
                line = [ rule[k] for k in PgHbaHDR if k in rule.keys() ]
                rule['line'] = "\t".join(line)

                #return a rule per db per user
                yield rule

    def add_rule(self, rule):
        '''
        This function adds (or replaces) a new rule.
        It tries to find original and checks for differences.
        If original doesn't exist, new rule is added.
        If original exists, but differs, it is replaced by the new rule.
        '''
        #First find the key
        key = self.rule2key(rule)
        try:
            #Try to find the original rule with this key
            oldrule = self.rules[key]
            #find keys of elements in the original rule
            ekeys = set(oldrule.keys() + rule.keys())
            #But skip line (that doesn;t need to be exactly the same)
            ekeys.remove('line')
            for k in ekeys:
                #Loop through keys and check values with new rule
                if oldrule[k] != rule[k]:
                    #A value is different. So, go to the exception block and replace the rule
                    raise Exception('')
        except:
            #Seems that original rule differs from new, or doesn't exist. Add new rule (in its place)
            self.rules[key] = rule
            #Also tell hba object that it is changed since last reading from or writing to file
            self.changed = True
            
    def remove_rule(self, rule):
        '''
        This procedure finds a rule and removes it from the object.
        '''
        #First find the key of the rule
        keys = self.rule2key(rule)
        try:
            #Try to remove the rule
            del self.rules[keys]
            #Found and removed. Tell hba object that it is changed since last reading from or writing to file
            self.changed = True
        except:
            pass
        
    def get_rules(self):
        '''
        This function returns a list of all the rules.
        '''
        ret = []
        for rk in self.rules.keys():
            #This zip of list comprehension basically creates a copy of the rule
            #but without the 'line' item. It creates a copy rather than modifying the original.
            rule = dict( [ (k, rules[rk][k]) for k in rules[rk].keys() if k != 'line' ] )
            #Return this rule
            yield(rule)

    def render(self):
        '''
        This function returns the contents that the altered pg_hba file should have.
        '''
        #First return the comments that where already there, line by line
        for comment in self.comment:
            yield(comment)
        #Then sort the rules by the weight of the rules and return them ruke by rule
        for rule in sorted(self.rules.values(), key=self.rule2weight):
            yield(rule['line'])

# ===========================================
# Module execution.
#

if __name__ == "__main__":

    #Declare the argument parser
    import argparse
    parser = argparse.ArgumentParser(description='Modify entries in pg_hba')
    parser.add_argument('-b', '--backup',         help='Create a backup of the file before changing it.', action='store_true')
    parser.add_argument('-c', '--create',         help="Create the file if it doesn't exist",             action='store_true')
    parser.add_argument(      '--check',          help="Only check if changes are required.",             action='store_true')
    parser.add_argument('-d', '--databases',      help='List of databases',                               default='all')
    parser.add_argument('-f', '--file', '--dest', help='Path to file',                                    default='')
    parser.add_argument('-g', '--group',          help='Default group ownership of file',                 default='postgres')
    parser.add_argument('--mode',                 help='Default access mode of file',                     default='640')
    parser.add_argument('-m', '--method',         help='pg_hba connection method',                        default='md5')
    parser.add_argument('-n', '--netmask',        help='Connection netmask',                              default='')
    parser.add_argument('--owner',                help='Default ownership of file',                       default='postgres')
    parser.add_argument('--options',              help='Connection options',                              default='')
    parser.add_argument('-o', '--order',          help='Order in hba file',                               default='sdu')
    parser.add_argument('--state',                help='Should it be present or absent',                  default='present')
    parser.add_argument('-r', '--reload',         help='Reload config when changed and postgres running', action='store_true')
    parser.add_argument('-s', '--source',         help='Source network',                                  default='samehost')
    parser.add_argument('-t', '--contype',        help='Connection type',                                 default='host')
    parser.add_argument('-u', '--users',          help='List of users',                                   default='all')

    #Parse the arguments
    options = parser.parse_args()

    #Find the expanded path of the file. '~' is expanded to $HOMEDIR, and 'subfolder/../' is expanded to '/'.
    dest      = os.path.expanduser(options.file)

    #If the file should exist, test if it exists, or create it
    if dest and options.create:
        touch(dest, options.owner, options.group, options.mode)
    #Parse the hba file
    pg_hba = PgHba(dest, options.order, options.backup)

    if options.contype:
        #Generate the new rules
        for rule in pg_hba.new_rules(options.contype, options.databases, options.users, options.source, options.netmask, options.method, options.options):
            if options.state == "present":
                #Add the rule
                pg_hba.add_rule(rule)
            else:
                #Remove the rule
                pg_hba.remove_rule(rule)
        if options.check:
            #Only pretend
            if pg_hba.changed:
                #Changed, so return exitcode other then 0
                sys.exit(1)
            else:
                #Not changed, so return 0
                sys.exit(0)
        else:
            #Write contents (write cecks if it has changed and if not, skips)
            pg_hba.write(options.reload)
