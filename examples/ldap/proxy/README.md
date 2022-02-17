# OpenLDAP Proxy

OpenLDAP has a backend called `meta` which basically is a LDAP proxy.

It supports:

* Simple bind with users from different LDAPs
* Searching multiple LDAPs with a single search query
* Rewrite of Domains and Attributes

````
AD 1 ----- 
         |
         ------ OpenLDAP Proxy ---- Confluent MDS 
         |
AD 2 -----
````
