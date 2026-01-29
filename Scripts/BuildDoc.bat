@echo OFF

echo Building XHTML documentation
..\Bin\DracoolaDoc -doc -f=xhtml -i=..\Doc\DracoolaDoc\Imaging.vdocproj -o=..\Doc

echo Building HTMLHelp documentation
..\Bin\DracoolaDoc -doc -f=htmlhelp -i=..\Doc\DracoolaDoc\Imaging.vdocproj -o=..\Doc
