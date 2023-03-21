#!/usr/bin/bash

SPEECH_KEY=
SPEECH_REGION=westus2


#  Get $filename without extension
filename=$1
filename="${filename%.*}"
filename_en="$filename-en.txt"
filename_cn="$filename-cn.srt"
filename_MP4="$filename-cn.mp4"
filename_wm_mp4="$filename-wm.mp4"
ssas=""
dsas=""
sendpoint=""
dendpoint=""
translator_endpoint=""
translator_region=""
translate_key=""

python captioning.py --input $1 --format any --output $filename_en --srt --realTime --threshold 20 --delay 0  --lines  1  --key $SPEECH_KEY --region $SPEECH_REGION

# use curl to upload  $filename_en to Azure Blob Storage $sendpoint with $ssas token
curl -X PUT -T $filename_en -H "x-ms-blob-type: BlockBlob" "$sendpoint/$filename_en?$ssas"

# call azure document translation service to translate $filename_en to $filename_cn

curl "$translator_endpoint/translator/text/batch/v1.0/batches" -i -X POST --header "Content-Type: application/json" --header "Ocp-Apim-Subscription-Key: $translate_key" --data "@document.json"


# call curl and return to $status, check if $status is 200
status=$(curl -s -o /dev/null -w "%{http_code}" "$dendpoint/$filename_en?$dsas")

#check if $status is 200, if not, while loop to wait for it
while [ $status != 200 ]
do
    echo "waiting for translation"
    sleep 5
    status=$(curl -s -o /dev/null -w "%{http_code}" "$dendpoint/$filename_en?$dsas")
done

#download $filename_cn from Azure Blob Storage $dendpoint with $dsas token
curl -X GET -H "x-ms-blob-type: BlockBlob" "$dendpoint/$filename_en?$dsas" -o $filename_cn

# delete $filename_en and $filename_cn from Azure Blob Storage $sendpoint and $dendpoint with $ssas and $dsas token
curl -X DELETE "$sendpoint/$filename_en?$ssas"
curl -X DELETE "$dendpoint/$filename_en?$dsas"

# call ffmpeg to add $filename_cn to $filename_MP4 and output to $filename_wm_mp4
ffmpeg -i $1 -vf subtitles=$filename_cn $filename_MP4

#call ffmepeg to add watermark to $filename_wm_mp4 and output to $filename_wm_mp4
ffmpeg -i $filename_MP4 -i watermark.png -filter_complex "overlay=10:10" $filename_wm_mp4



# if "captioned-video" folder not exist, create it
if [ ! -d "captioned-video" ]; then
    mkdir captioned-video
fi

#move $filename_wm_mp4 to "captioned-video" folder
mv $filename* captioned-video

# echo all done.
echo "All done."