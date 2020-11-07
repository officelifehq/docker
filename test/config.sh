#!/usr/bin/env bash

globalTests+=(
	utc
	cve-2014--shellshock
	no-hard-coded-passwords
	override-cmd
)

imageTests+=(
	[officelife]='
		officelife-cli
	'
	[officelife:apache]='
		officelife-apache-run
	'
	[officelife:fpm]='
		officelife-fpm-run
	'
	[officelife:fpm-alpine]='
		officelife-fpm-run
	'
)
