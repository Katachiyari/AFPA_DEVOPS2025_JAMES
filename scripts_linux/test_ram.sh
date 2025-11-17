#!/bin/bash
user=$(whoami)

if groups $user | grep -qw "sudo"; then
	echo "script OK"
else
	echo "vous devez être sudo pour executer le script"
fi
