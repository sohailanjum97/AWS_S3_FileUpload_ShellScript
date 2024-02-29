#!/bin/sh
yyyymmdd=`date +%Y%m%d`
isoDate=`date --utc +%Y%m%dT%H%M%SZ`
# EDIT the next 4 variables to match your account
s3Bucket="bucketsamtest"
bucketLocation="*****************region name*********" 
s3AccessKey="*******************"
s3SecretKey="***************************"

#endpoint="${s3Bucket}.s3-${bucketLocation}.amazonaws.com"
endpoint="s3-${bucketLocation}.amazonaws.com"

fileName="/home/devops/$file_name"
contentLength=`cat ${fileName} | wc -c`
contentHash=`openssl sha256 -hex ${fileName} | sed 's/.* //'`

canonicalRequest="PUT\n/${s3Bucket}/${fileName}\n\ncontent-length:${contentLength}\nhost:${endpoint}\nx-amz-content-sha256:${contentHash}\nx-amz-date:${isoDate}\n\ncontent-length;host;x-amz-content-sha256;x-amz-date\n${contentHash}"
canonicalRequestHash=`echo -en ${canonicalRequest} | openssl sha256 -hex | sed 's/.* //'`

stringToSign="AWS4-HMAC-SHA256\n${isoDate}\n${yyyymmdd}/${bucketLocation}/s3/aws4_request\n${canonicalRequestHash}"

echo "----------------- canonicalRequest --------------------"
echo -e ${canonicalRequest}
echo "----------------- stringToSign --------------------"
echo -e ${stringToSign}
echo "-------------------------------------------------------"

# calculate the signing key
DateKey=`echo -n "${yyyymmdd}" | openssl sha256 -hex -hmac "AWS4${s3SecretKey}" | sed 's/.* //'`
DateRegionKey=`echo -n "${bucketLocation}" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateKey} | sed 's/.* //'`
DateRegionServiceKey=`echo -n "s3" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateRegionKey} | sed 's/.* //'`
SigningKey=`echo -n "aws4_request" | openssl sha256 -hex -mac HMAC -macopt hexkey:${DateRegionServiceKey} | sed 's/.* //'`
# then, once more a HMAC for the signature
signature=`echo -en ${stringToSign} | openssl sha256 -hex -mac HMAC -macopt hexkey:${SigningKey} | sed 's/.* //'`

authoriz="Authorization: AWS4-HMAC-SHA256 Credential=${s3AccessKey}/${yyyymmdd}/${bucketLocation}/s3/aws4_request, SignedHeaders=content-length;host;x-amz-content-sha256;x-amz-date, Signature=${signature}"

curl -v -X PUT -T "${fileName}" \
-H "Host: ${endpoint}" \
-H "Content-Length: ${contentLength}" \
-H "x-amz-date: ${isoDate}" \
-H "x-amz-content-sha256: ${contentHash}" \
-H "${authoriz}" \
http://${endpoint}/${s3Bucket}/${fileName}
