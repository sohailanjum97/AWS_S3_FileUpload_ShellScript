#!/bin/bash
# Function to find and copy the file

weekly="WKLY"
weekdays="WKDY"
monthly="MHLY"
timestamp=$(date +%d-%m-%Y_%H-%M-%S)
#Get the day of the week after updating timezone ..
    timing=$(date +%u)
    if [ `expr $timing % 7` == 5 ]; then
        date_type=$weekly
    else
        date_type=$weekdays
    fi
    # 暫時不需判斷weekly or daily 2023/1/13 註解上5行  
    
    currentday=$(date +%d)
    lastday=`date -d "$(date +%Y-%m-01) +1 month -1 day" +%d`
    if [ $currentday == $lastday ]; then
        date_type=$monthly
        imageBuild="-i"
        SDK="-s"
    fi
#function to copy file
copy_file() 
{
 echo "before cd: $(pwd)"
        cd
        echo "This is home directory : $(pwd)"
        su dev
        cd /home/dev/$date_type/$module/mt6890/openwrt # Replace with the path to the specific folder
 echo "after cd: $(pwd)"
          file_name=$(./scripts/create_xs_revision.sh).bin
 echo "Generated filename: $file_name"
 echo "Current directory: $(pwd)"
   if [ -f "home/dev/$file_name" ]; then
      cp -f /home/dev/$date_type/$module/mt6890/openwrt/bin/targets/gem6xxx/xs5g01_$module/$file_name /home/dev/
   else
      cp /home/dev/$date_type/$module/mt6890/openwrt/bin/targets/gem6xxx/xs5g01_$module/$file_name /home/dev/
   fi
}

s3upload()
{
copy_file
echo "file copied successfully"
echo "$file_name"

yyyymmdd=`date +%Y%m%d`
isoDate=`date --utc +%Y%m%dT%H%M%SZ`
# EDIT the next 4 variables to match your account
# EDIT the next 4 variables to match your account
s3Bucket="*********bucket_name************"
bucketLocation="**********region_name********"
s3AccessKey="****************"
s3SecretKey="******************************"

#endpoint="${s3Bucket}.s3-${bucketLocation}.amazonaws.com"
endpoint="s3-${bucketLocation}.amazonaws.com"

fileName="/home/dev/$file_name"
PURE_FILE=`basename $fileName`
contentLength=`cat ${fileName} | wc -c`
contentHash=`openssl sha256 -hex ${fileName} | sed 's/.* //'`

canonicalRequest="PUT\n/${s3Bucket}/${PURE_FILE}\n\ncontent-length:${contentLength}\nhost:${endpoint}\nx-amz-content-sha256:${contentHash}\nx-amz-date:${isoDate}\n\ncontent-length;host;x-amz-content-sha256;x-amz-date\n${contentHash}"
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
http://${endpoint}/${s3Bucket}/${PURE_FILE}

}


while getopts "m:" name; do
   case $name in
      m) module=$OPTARG;;
      ?) usage;;
   esac
done

echo "======module=$module======"

copy_file
s3upload
