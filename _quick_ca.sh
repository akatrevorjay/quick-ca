#!/bin/bash -e
#
# ~ Quick hack to generate a CA and server certs in a hurry
#
# You'll need to edit caconfig.cnf to change the paths from /etc/ssl/ca, unless you actually use, well, /etc/ssl/ca.
#
# @author Trevor Joynson, trevorj at skywww dot net
# @version $Id$
#
#TODO Create openssl confs on the fly from vars here
#

OPENSSL_CA_CONF="caconfig.cnf"
SERVER_CERTS="$@"

CA_KEY="cacert.pem"
CA_DER="cacert.der"

function e      { echo "[`date "+%D %r"`] [$0] $*"; }
function debug  { [[ -z "$DEBUG" ]] || e DEBUG: $*; }
function error  { e ERROR: $* >&2; }
function death  { error $*; exit 1; }

if [[ ! -f "$OPENSSL_CA_CONF" ]]; then
	death "No config file found for OPENSSL_CA_CONF=$OPENSSL_CA_CONF"; exit 1
fi

##
## CA generation
##

for i in private signedcerts; do
	if [[ ! -d "$i" ]]; then
		e "Creating directory $i.." && mkdir -p "$i"
	fi
done

export OPENSSL_CONF="$OPENSSL_CA_CONF"

if [[ ! -f "$CA_KEY" ]]; then
	e
	e "Generating new CA key..."
	e
	openssl req -x509 -newkey rsa:2048 -out "$CA_KEY" -outform PEM -days 1825
	CA_CONT=1

	if [[ ! -f "$CA_KEY" ]]; then
		death "No CA_KEY=$CA_KEY was created, something went wrong during generation. Cannot continue."; exit 1
	fi
fi

if [[ $CA_CONT>0 || ! -f "$CA_DER" ]]; then
	e
	e "Generating new DER export of CA key..."
	e
	openssl x509 -in "$CA_KEY" -out "$CA_DER" -outform DER
	CA_CONT=1

	if [[ ! -f "$CA_DER" ]]; then
		death "No CA_DER=$CA_DER was created, something went wrong during generation. Cannot continue."; exit 1
	fi
fi

##
## Server Cert generation
##

# If there are no server certs to be made, exit nicely
[[ "$*" == "" ]] && exit 0

e "Looping through [$SERVER_CERTS].."

for c in $SERVER_CERTS; do
	e
	e "Generating cert $c.."
	e

	OPENSSL_SERVER_CONF="server_${c}.cnf"
	
	if [[ ! -f "$OPENSSL_SERVER_CONF" ]]; then
		death "No config file found for OPENSSL_SERVER_CONF=$OPENSSL_SERVER_CONF"; exit 1
	fi
	
	export OPENSSL_CONF="$OPENSSL_SERVER_CONF"
	
	KEY_REQ="server_${c}_req.pem"
	KEY_ENC="server_${c}_key_enc.pem"
	KEY_DEC="server_${c}_key.pem"
	KEY_CRT="server_${c}.crt"
	KEY_CONT=0
	
	if [[ ! -f "$KEY_ENC" || ! -f "$KEY_REQ" ]]; then
		e
		e "Generating request and encrypted key..."
		e
		openssl req -newkey rsa:1024 -keyout "$KEY_ENC" -keyform PEM -out "$KEY_REQ" -outform PEM
		KEY_CONT=1
	
		if [[ ! -f "$KEY_ENC" || ! -f "$KEY_REQ" ]]; then
			death "No KEY_ENC=$KEY_ENC or KEY_REQ=$KEY_REQ was created, something went wrong during generation. Cannot continue."; exit 1
		fi
	fi
	
	if [[ $KEY_CONT>0 || ! -f "$KEY_DEC" ]]; then
		e
		e "Generating decrypted key..."
		e
		openssl rsa < "$KEY_ENC" > "$KEY_DEC"
		KEY_CONT=1
		
		if [[ ! -f "$KEY_DEC" ]]; then
			death "No KEY_DEC=$KEY_DEC was created, something went wrong during decryption. Cannot continue."; exit 1
		fi
	fi

	export OPENSSL_CONF="$OPENSSL_CA_CONF"
	
	if [[ $KEY_CONT>0 || ! -f "$KEY_CRT" ]]; then
		e
		e "CA Signing key..."
		e
		openssl ca -in "$KEY_REQ" -out "$KEY_CRT"
		KEY_CONT=1
	
		if [[ ! -f "$KEY_CRT" ]]; then
			death "No KEY_CRT=$KEY_CRT was created, something went wrong during signing. Cannot continue."; exit 1
		fi
	fi
done

