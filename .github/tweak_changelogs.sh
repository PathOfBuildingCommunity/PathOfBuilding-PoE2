#!/bin/bash

RELEASE_VERSION="$1"

# Delete until the first line containing "--"
sed -i '1,/--/d' temp_change.md
# Reverse the order of lines in the file (last line becomes first, etc.)
sed -i '1h;1d;$!H;$!d;G' temp_change.md
# Convert "**Full Changelog**: URL" format to markdown link format "[Full Changelog](URL)"
sed -i -re 's/\*\*Full Changelog\*\*: (.*)/\[Full Changelog\]\(\1\)\n/' temp_change.md
# Delete everything from "## New Contributors" line to the end of file
sed -i '/## New Contributors/,$d' temp_change.md
# Convert GitHub changelog entries from "* description by @username in pull/URL/number"
# to "- description [#number](pull/URL/number) ([username](https://github.com/username))" format
sed -i -re 's/^\*(.*)\sby\s@(.*)\sin\s(.*\/pull\/)(.*)/-\1 [\\#\4](\3\4) ([\2](https:\/\/github.com\/\2))/' temp_change.md
# Username substitutions for preferred display names
sed -i 's/\[Quotae/\[Quote_a/' temp_change.md
sed -i 's/\[learn2draw/\[Lexy/' temp_change.md
sed -i 's/\[Voronoff/\[Tom Clancy Is Dead/' temp_change.md
sed -i 's/\[PJacek/\[TPlant/' temp_change.md
sed -i 's/\[justjuangui/\[trompetin17/' temp_change.md

cp temp_change.md changelog_temp.txt
# Append existing CHANGELOG.md content (excluding first line) to temp_change.md
sed '1d' CHANGELOG.md >> temp_change.md
# Create new CHANGELOG.md with header containing version and date, followed by processed changes
printf "# Changelog\n\n## [$RELEASE_VERSION](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/tree/$RELEASE_VERSION) ($(date +'%Y/%m/%d'))\n\n" | cat - temp_change.md > CHANGELOG.md
# Convert changelog entries from markdown link format to simplified "* description (username)" format
sed -i -re 's/^- (.*) \[.*\) \(\[(.*)\]\(.*/* \1 (\2)/' changelog_temp.txt
# Create new changelog format: add version header, remove lines 2-3, format section headers, remove ## headers with following line, prepend to existing changelog
echo "VERSION[${RELEASE_VERSION#v}][$(date +'%Y/%m/%d')]" | cat - changelog_temp.txt | sed '2,3d' | sed -re 's/^### (.*)/\n--- \1 ---/' | sed -e '/^##.*/,+1 d' | cat - changelog.txt > changelog_new.txt
mv changelog_new.txt changelog.txt

# Normalize line endings to CRLF for all output files to ensure consistent checksums with Windows
sed 's/\r*$/\r/' CHANGELOG.md > CHANGELOG_normalized.md && mv CHANGELOG_normalized.md CHANGELOG.md
sed 's/\r*$/\r/' changelog.txt > changelog_normalized.txt && mv changelog_normalized.txt changelog.txt

# Clean up temporary files
rm temp_change.md
rm changelog_temp.txt
