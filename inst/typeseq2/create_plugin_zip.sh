rm -R TypeSeq2-Dev_stable
mkdir TypeSeq2-Dev_stable

# ion torrent plugin specific files
cp inst/typeseq2/instance.html TypeSeq2-Dev_stable/
cp inst/typeseq2/launch.sh TypeSeq2-Dev_stable/
cp inst/typeseq2/plan.html TypeSeq2-Dev_stable/
cp inst/typeseq2/pluginsettings.json TypeSeq2-Dev_stable/

# zip plugin package
zip -r TypeSeq2-Dev_stable.zip TypeSeq2-Dev_stable