BUILD_DIR=
GITHUB_ACCESS_TOKEN=
BRANCH="circles"
SCHEME="Circles for Telegram"
USER=
PASSWORD=
TEAM="WDEGJM2L33"
BUILD_PATH=

read -p 'Version: ' VERSION

echo '<h3>Release Notes:</h3>' > /tmp/release_notes.html
vim /tmp/release_notes.html
RELEASE_NOTES=$(cat /tmp/release_notes.html)
pandoc -f html -t markdown -i /tmp/release_notes.html -o /tmp/release_notes.md
RELEASE_NOTES_MD=$(cat /tmp/release_notes.md)


echo "archiving app..."
ditto -c -k --sequesterRsrc --keepParent "$BUILD_PATH/$SCHEME.app" updates/circles-$VERSION.zip

echo "appcast and deltas generation..."
$BUILD_DIR/DebugAppStore/generate_appcast updates

echo "fixing release download paths"
xmlstarlet sel -t -m '/rss/channel/item/title' -v 'text()' -n updates/appcast.xml | while read version
do
  if [ "$version" == "$VERSION" ]
  then
    xmlstarlet ed -L -i "/rss/channel/item/title[text()=\"$version\"]" -t elem -n description -v "$RELEASE_NOTES" updates/appcast.xml
  fi
  xmlstarlet ed -L -u "/rss/channel/item/title[text()=\"$version\"]/../enclosure/@url" -v "https://github.com/Shimbo/TelegramSwift/releases/download/$version/circles-$version.zip" updates/appcast.xml
done
 
echo "github release creation"
API_JSON=$( jq -n \
  --arg tag_name "$VERSION" \
  --arg target_commitish "$BRANCH" \
  --arg name "$VERSION" \
  --arg body "$RELEASE_NOTES_MD" \
  '{tag_name: $tag_name, target_commitish: $target_commitish ,name: $name, body: $body, draft: false, prerelease: true}' )

RELEASE_RESPONSE=$(curl --data "$API_JSON" https://api.github.com/repos/Shimbo/TelegramSwift/releases?access_token=$GITHUB_ACCESS_TOKEN)

UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq --raw-output '.upload_url' | sed -e "s/{?name,label}//")
echo "upload url: $UPLOAD_URL"

echo "uploading files..."
UPLOAD_ZIP_URL="$UPLOAD_URL?name=circles-$VERSION.zip&access_token=$GITHUB_ACCESS_TOKEN"
curl --data-binary @updates/circles-$VERSION.zip -H 'Content-Type: application/zip' "$UPLOAD_ZIP_URL"

xmlstarlet sel -t -m '/rss/channel/item/sparkle:deltas/enclosure' -v 'concat(concat(@sparkle:deltaFrom,";",@sparkle:version),";",@sparkle:shortVersionString)' -n updates/appcast.xml | while read info
do
  echo $info
  from=$(echo $info | cut -d';' -f1) 
  to=$(echo $info | cut -d';' -f2) 
  version=$(echo $info | cut -d';' -f3)

  DELTA_NAME="Circles for Telegram$to-$from.delta"
  DELTA_NAME_ESCAPED="Circles.for.Telegram$to-$from.delta"

  xmlstarlet ed -L -u "/rss/channel/item/title[text()=\"$version\"]/../sparkle:deltas/enclosure[@sparkle:deltaFrom=\"$from\"]/@url" -v "https://github.com/Shimbo/TelegramSwift/releases/download/$version/$DELTA_NAME_ESCAPED" updates/appcast.xml

  if [ "$version" == "$VERSION" ]
  then
	  UPLOAD_DELTA_URL="$UPLOAD_URL?name=$DELTA_NAME_ESCAPED&access_token=$GITHUB_ACCESS_TOKEN"
	  echo "Upload delta url: $UPLOAD_DELTA_URL"
	  curl -T "updates/$DELTA_NAME" -H 'Content-Type: application/octet-stream' "$UPLOAD_DELTA_URL"
  fi
  
done
