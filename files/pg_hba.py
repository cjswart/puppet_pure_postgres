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
This exception is raised by the PgHba object when an issue arises
'''
class PgHbaError(Exception):
    pass

class PgHba(object):
    """
    PgHba object to read/write entries to/from.

    pg_hba_file - the pg_hba file almost always /etc/pg_hba
    """
    def __init__(self, pg_hba_file=None, order="sdu", backup=False):
        if order not in PgHbaOrders:
            raise PgHbaError("invalid order setting {0} (should be one of '{1}').".format(order, "', '".join(PgHbaOrders)))
        self.pg_hba_file = pg_hba_file
        self.rules      = None
        self.comment    = None
        self.changed    = True
        self.order      = order
        self.backup     = backup

        #self.databases will be update by add_rule and gives some idea of the number of databases (at least that are handled by this pg_hba)
        self.databases  = set(['postgres', 'template0','template1'])

        #self.databases will be update by add_rule and gives some idea of the number of users (at least that are handled by this pg_hba)
        #since this migth also be groups with multiple users, this migth be totally off, but at least it is some info...
        self.users      = set(['postgres'])

        # select whether we dump additional debug info through syslog
        self.syslogging = False

        self.read()

    def read(self):
        # Read in the pg_hba from the system
        self.rules = {}
        self.comment = []
        # read the pg_hbafile
        try:
            f = open(self.pg_hba_file, 'r')
            for l in f:
                l=l.strip()
                #uncomment
                if '#' in l:
                    l, comment = l.split('#', 1)
                    self.comment.append('#'+comment)
                rule = self.line_to_rule(l)
                if rule:
                    self.add_rule(rule)
            f.close()
            self.changed = False
        except IOError, e:
            raise PgHbaError("pg_hba file '{0}' doesn't exist. Use create option to autocreate.".format(self.pg_hba_file))

    def line_to_rule(self, line):
        #split into sid, home, enabled
        if split_re.sub('', line) == '':
            #empty line. skip this one...
            return None
        cols = split_re.split(line)
        if len(cols) < 4:
            raise PgHbaError("File {0} has a rule with too few columns: {1}.".format(self.pg_hba_file, line))
        if cols[0] not in PgHbaTypes:
            raise PgHbaError("File {0} contains an rule of unknown type: {1}.".format(self.pg_hba_file, line))
        if cols[0] == 'local':
            if cols[3] not in PgHbaMethods:
                raise PgHbaError("File {0} contains an rule of 'local' type where 4th column '{1}'isnt a valid auth-method.".format(self.pg_hba_file, cols[3]))
            cols.insert(3, None)
            cols.insert(3, None)
        else:
            if len(cols) < 6:
                cols.insert(4, None)
            elif cols[5] not in PgHbaMethods:
                cols.insert(4, None)
            if len(cols) < 7:
                cols.insert(7, None)
            if cols[5] not in PgHbaMethods:
                raise PgHbaError("File {0} contains an rule '{1}' that has no valid method.".format(self.pg_hba_file, line))
        rule = dict(zip(PgHbaHDR, cols[:7]))
        self.cleanEmptyRuleKeys(rule)
        rule['line'] = line
        return rule

    def cleanEmptyRuleKeys(self, rule):
        for k in rule.keys():
            if not rule[k]:
                del rule[k]

    def rule2key(self, rule):
        if rule['type'] == 'local':
            source = 'local'
        elif ipv4_re.search(rule['src']):
            if '/' in rule['src']:
                nw, prefix = rule['src'].split('/')
                netmask = prefix_to_ipv4netmask(prefix)
                source = nw+'/'+netmask
            elif 'mask' not in rule.keys():
                source = rule['src']+'/255.255.255.255'
            else:
                source = rule['src']+'/'+rule['mask']
        elif ipv6_re.search(rule['src']):
            if '/' in rule['src']:
                nw, prefix = rule['src'].split('/')
                netmask = prefix_to_ipv6netmask(prefix)
                source = nw+'/'+netmask
            elif 'mask' not in rule.keys():
                source = rule['src']+'/ffff:ffff:ffff:ffff:ffff:ffff'
            else:
                source = rule['src']+'/'+rule['mask']
        else:
            source = rule['src']

        return (source, rule['db'], rule['usr'])

    def rule2weight(self, rule):
        # For networks, every 1 in 'netmask in binary' makes the subnet more specific.
        # Therefore I chose to use prefix as the weight.
        # So a single IP (/32) should have twice the weight of a /16 network.
        # To keep everything in the same wieght scale for IPv6, I chose 
        # - a scale of 0 - 128 from 0 bits to 32 bits for ipv4 and 
        # - a scale of 0 - 128 from 0 bits to 128 bits for ipv6.
        if rule['type'] == 'local':
            #local is always 'this server' and therefore considered /32
            srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
        elif ipv4_re.search(rule['src']):
            if '/' in rule['src']:
                #prefix tells how much 1's there are in netmask, so lets use that for sourceweight
                prefix = rule['src'].split('/')[1]
                srcweight = int(prefix) * 4
            elif 'mask' in rule.keys():
               #Netmask. Let's count the 1's in the netmask in binary form.
                bits = "{0:b}".format(ipv4_to_int(rule['mask']))
                srcweight = bits.count('1') * 4
            else:
                #seems, there is no netmask / prefix to be found. Then only one IP applies.
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
        elif ipv6_re.search(rule['src']):
            if '/' in rule['src']:
                #prefix tells how much 1's there are in netmask, so lets use that for sourceweight
                prefix = rule['src'].split('/')[1]
                srcweight = int(prefix)
            elif 'mask' in rule.keys():
               #Netmask. Let's count the 1's in the netmask in binary form.
                bits = "{0:b}".format(ipv6_to_int(rule['mask']))
                srcweight = bits.count('1') * 4
            else:
                #seems, there is no netmask / prefix to be found. Then only one IP applies.
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
        else:
            #You can also write all to match any IP address, samehost to match any of the server's own IP addresses, or samenet to match any address in any subnet that the server is directly connected to.
            if rule['src'] == 'all':
                srcweight = 0
            elif rule['src'] == 'samehost':
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)
            elif rule['src'] == 'samenet':
                #Might write some fancy code to determine all prefix's 
                #from all interfaces and find a sane value for this one.
                #For now, let's assume /24...
                srcweight = 96 #(ipv4 /24 is considered equivalent to ipv6 /96)
            elif rule['src'][0] == '.':
                # suffix matching, let's asume a very large scale and therefore a very low weight.
                srcweight = 64 #(ipv4 /16 is considered equivalent to ipv6 /64)
            else:
                #hostname, let's asume only one host matches
                srcweight = 128 #(ipv4 /32 is considered equivalent to ipv6 /128)

        #One little thing: for db and user weight, higher weight means less specific and thus lower in the file.
        #Since prefix is higher for more specific, I inverse the output to align with how dbweight and userweight works...
        srcweight = 128 - srcweight #(higher prefix should be lower weight)

        if rule['db'] == 'all':
            dbweight = len(self.databases) + 1
        elif rule['db'] == 'replication':
            dbweight = 0
        elif rule['db'] in [ 'samerole', 'samegroup']:
            dbweight = 1
        else:
            dbweight = 1 + rule['db'].count(',')

        if rule['usr'] == 'all':
            uweight = len(self.users) + 1
        else:
            uweight = 1

        ret = []
        for c in self.order:
            if c == 'u':
                ret.append(uweight)
            elif c == 's':
                ret.append(srcweight)
            elif c == 'd':
                ret.append(dbweight)

        return tuple(ret)

    def log_message(self, message):
        if self.syslogging:
            syslog.syslog(syslog.LOG_NOTICE, 'ansible: "%s"' % message)

    def is_empty(self):
        if len(self.rules) == 0:
            return True
        else:
            return False

    def reload(self):
        if self.changed:
            try:
                subprocess.call(['/etc/init.d/postgres', 'reload'])
            except:
                pass

    def write(self, reload=False):
        if not self.changed:
            return

        if self.pg_hba_file:
            if self.backup:
                backup_file_h, backup_file = tempfile.mkstemp(prefix='pg_hba')
                shutil.copy(self.pg_hba_file, backup_file)
            fileh = open(self.pg_hba_file, 'w')
        else:
            filed, path = tempfile.mkstemp(prefix='pg_hba')
            fileh = os.fdopen(filed, 'w')

        fileh.write(self.render())
        if reload:
            self.reload()
        self.changed = False
        fileh.close()

    def new_rules(self, contype, databases, users, source, netmask, method, options):
        if method not in PgHbaMethods:
            raise PgHbaError("invalid method {0} (should be one of '{1}').".format(method, "', '".join(PgHbaMethods)))
        if contype not in PgHbaTypes:
            raise PgHbaError("invalid connection type {0} (should be one of '{1}').".format(contype, "', '".join(PgHbaTypes)))

        for db in databases.split(','):
            for usr in users.split(','):

                rule = dict(zip(PgHbaHDR, [contype, db, usr, source, netmask, method, options]))

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

                self.cleanEmptyRuleKeys(rule)

                line = [ rule[k] for k in PgHbaHDR if k in rule.keys() ]
                rule['line'] = "\t".join(line)
                yield rule

    def add_rule(self, rule):
        key = self.rule2key(rule)
        try:
            oldrule = self.rules[key]
            ekeys = set(oldrule.keys() + rule.keys())
            ekeys.remove('line')
            for k in ekeys:
                if oldrule[k] != rule[k]:
                    raise Exception('')
        except:
            self.rules[key] = rule
            self.changed = True
            if rule['db'] not in [ 'all', 'samerole', 'samegroup', 'replication' ]:
                databases = set(rule['db'].split(','))
                self.databases.update(databases)
            if rule['usr'] != 'all':
                user = rule['usr']
                if user[0] == '+':
                    user = user[1:]
                self.users.add(user)

    def remove_rule(self, rule):
        keys = self.rule2key(rule)
        try:
            del self.rules[keys]
            self.changed = True
        except:
            pass
        
    def get_rules(self):
        ret = []
        for k in self.rules.keys():
            rule = self.rules[k]
            del rule['line']
            ret.append(rule)
        return ret

    def render(self):
        comment = '\n'.join(self.comment)
        sorted_rules = sorted(self.rules.values(), key=self.rule2weight)
        rule_lines = '\n'.join([ r['line'] for r in sorted_rules ])
        result = comment+'\n'+rule_lines
        #End it properly with a linefeed (if not already).
        if result and result[-1] not in ['\n', '\r']:
            result += '\n'
        return result

# ===========================================
# Module execution.
#

if __name__ == "__main__":

    import argparse
    parser = argparse.ArgumentParser(description='Modify entries in pg_hba')
    parser.add_argument('-b', '--backup',         help='Create a backup of the file before changing it.', action='store_true')
    parser.add_argument('-c', '--create',         help="Create the file if it doesn't exist",             action='store_false')
    parser.add_argument(      '--check',          help="Only check if changes are required.",             action='store_true')
    parser.add_argument('-d', '--databases',      help='List of databases',                               default='all')
    parser.add_argument('-f', '--file', '--dest', help='Path to file',                                    default='/etc/pgpure/postgres/9.6/data/pg_hba.conf')
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

    options = parser.parse_args()

    dest      = os.path.expanduser(options.file)

    if options.create:
        touch(dest, options.owner, options.group, options.mode)
    pg_hba = PgHba(dest, options.order, options.backup)

    if options.contype:
        for rule in pg_hba.new_rules(options.contype, options.databases, options.users, options.source, options.netmask, options.method, options.options):
            if options.state == "present":
                pg_hba.add_rule(rule)
            else:
                pg_hba.remove_rule(rule)
        if options.check:
            if pg_hba.changed:
                sys.exit(1)
            else:
                sys.exit(0)
        else:
            pg_hba.write(options.reload)
