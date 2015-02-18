#!/usr/bin/env bash
# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Kill script for use as the parameter of OpenJDK's -XX:OnOutOfMemoryError

set -e

upload_to_s3() {
    file=$1
	bucket=$(cat /app/WEB-INF/classes/AWS_S3_BUCKET)
	resource="/${bucket}/${file}"
	contentType="text/plain"
	dateValue=`date -R`

	stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
	s3Key=$(cat /app/WEB-INF/classes/AWS_ACCESS_KEY)
	s3Secret=$(cat /app/WEB-INF/classes/AWS_SECRET_KEY)
	signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
	echo "https://${bucket}.s3.amazonaws.com/${file}"

	curl -X PUT -T "${file}" \
	  -H "Host: ${bucket}.s3.amazonaws.com" \
	  -H "Date: ${dateValue}" \
	  -H "Content-Type: ${contentType}" \
	  -H "Authorization: AWS ${s3Key}:${signature}" \
	  https://${bucket}.s3.amazonaws.com/${file}
}

timestamp=`date +%Y-%m-%d:%H:%M:%S`
logFile=logFile${timestamp}.log

echo "
Process Status (Before)
=======================
$(ps -ef)

ulimit (Before)
===============
$(ulimit -a)

Free Disk Space (Before)
========================
$(df -h)
" >> /app/${logFile}

upload_to_s3 /app/heapDump.hprof

pkill -9 -f .*-XX:OnOutOfMemoryError=.*killjava.*

echo "
Process Status (After)
======================
$(ps -ef)

ulimit (After)
==============
$(ulimit -a)

Free Disk Space (After)
=======================
$(df -h)
" >> /app/${logFile}

upload_to_s3 /app/${logFile}
