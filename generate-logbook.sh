#!/bin/bash

#
# This script is Copyright (c) 2013 Akarsh Simha <akarsh.simha@kdemail.net> 
#
# This script is licensed under the GNU General Public License v2 or
# any later version at your convenience.
#
# Please see the LICENSE file for a copy of the GNU General Public
# License
#

#
# Generate a logbook for a given list of celestial objects.
#
# This script uses KStars and LaTeX to generate observing log books
# for a list of celestial objects.
#
# The objects must exist in KStars. KStars must be running and be
# accessible via qdbus.
#
# Dependencies: xmlstarlet, inkscape, pdflatex, kstars, ImageMagick (convert), pdftk
#

# Invokation: ./generate-logbook.sh <project name> [object list file] ["build" directory]

DEBUG="1"

if [ -z "$1" ]; then
    echo "ERROR: No project name supplied. The project name is the title of the logbook."
    echo "Invokation: ./generate-logbook.sh <project name> [object list file] [\"build\" directory]"
    exit 1;
else
    PROJECT_NAME=$1
fi;

if [ -z "$2" ]; then
    OBJECT_LIST='objectlist.txt'
else
    OBJECT_LIST=$2
fi;

if [ $DEBUG ]; then echo $OBJECT_LIST; fi;

if [ -z "$3" ]; then
    BUILD_DIR='build'
else
    BUILD_DIR=$3
fi;

if [ -z "$4" ]; then
    LOGO_FILE="logo.eps"
else
    LOGO_FILE=$4
fi;

if [ ! -f "$OBJECT_LIST" ]; then
    echo "Object list file " $OBJECT_LIST " not found."
    echo "Invokation: ./generate-logbook.sh <project name> [object list file] [\"build\" directory]"
    exit 1;
fi;

if [ ! -f "$LOGO_FILE" ]; then
    echo "Warning: Not a valid file: " $LOGO_FILE
    echo "Will not use any logo"
    LOGO_FILE=""
fi;

# Other settings
LOGO_SIZE=0.7 # Logo size in inches.
CITY_ICON="city.pdf"
BINOCULAR_ICON="binoculars.pdf"
TELESCOPE_ICON="kstars.pdf"

mkdir -p $BUILD_DIR; # Create the "build" directory

list='' # List of objects for final processing
checklist_count=10 # Count for objects in checklist to prevent overflowing the page. Start from 10 since the first page has a chapter title etc.
object_count=0 # Count of the number of objects, that doesn't reset
total_objects=`cat ${OBJECT_LIST} | wc -l` # Total number of objects

echo "" > ${BUILD_DIR}/Objects.tex
echo "" > ${BUILD_DIR}/ConstType.txt
echo "" > ${BUILD_DIR}/ObjectsByType.tex
echo "" > ${BUILD_DIR}/ObjectsByConstellation.tex

echo "\resizebox{\textwidth}{!}{
\centering
%\newcolumntype{C}{>{\centering\arraybackslash} m{0.1\textwidth}}
\begin{tabular}{|c|c|c|c|c|c||c|c|}
\hline
Object & Type & Constellation & Mag. & Size & Page & Obs. Date & Second Obs.\\\\
\hline
\hline
" > ${BUILD_DIR}/Checklist.tex

while read object_list_line; do

    if [ $DEBUG ]; then echo "Processing line: " $object_list_line; fi;

    object=`echo $object_list_line | awk -F'|' '{ print $1 }'` # Retrieve the name of the object from the list
    object_description=`echo $object_list_line | awk -F'|' '{ print $2 }'` # Retrieve a description of the object
    object_observability=`echo $object_list_line | awk -F'|' '{ print $3 }'` # Retrieve an observability string indicating whether the object is city / binocular observable

    if [ -n "$object_description" ]; then
	object_description_with_prefix="\textbf{Description:} $object_description";
    else
	object_description_with_prefix=""
    fi;

    if [ $DEBUG ]; then echo "Object: " $object; fi;

    object_underscored=`echo $object | sed 's/ /_/g'`; # An underscored copy of the object for use in file names etc

    if [ $DEBUG ]; then echo "Underscored: " $object_underscored; fi;

    XML=`qdbus org.kde.kstars /KStars org.kde.kstars.getObjectDataXML "$object"`
    maj_axis=`echo $XML | xmlstarlet sel -t -m "object" -v "Major_Axis"`
    min_axis=`echo $XML | xmlstarlet sel -t -m "object" -v "Minor_Axis"`
    RA_HMS=`echo $XML | xmlstarlet sel -t -m "object" -v "RA_HMS" | sed 's/\([hms]\)/^{\\\mathrm{\1}\\\,}/g'`
    RA_HMS_J2000=`echo $XML | xmlstarlet sel -t -m "object" -v "RA_J2000_HMS" | sed 's/\([hms]\)/^{\\\mathrm{\1}\\\\\,}/g'`
    Dec_DMS=`echo $XML | xmlstarlet sel -t -m "object" -v "Dec_DMS" | sed "s/°/\\\\\degree\\\\\,/;s/'/'\\\\\,/;s/\"/''\\\\\,/"` # SED needed because LaTeX doesn't like the degree symbol
    Dec_DMS_J2000=`echo $XML | xmlstarlet sel -t -m "object" -v "Dec_J2000_DMS" | sed "s/°/\\\\\degree\\\\\,/;s/'/'\\\\\,/;s/\"/''\\\\\,/"` # SED needed because LaTeX doesn't like the degree symbol
    mag=`echo $XML | xmlstarlet sel -t -m "object" -v "Magnitude"`
    Name=`echo $XML  | xmlstarlet sel -t -m "object" -v "Name"`
    Long_Name=`echo $XML  | xmlstarlet sel -t -m "object" -v "Long_Name"`
    Alt_Name=`echo $XML  | xmlstarlet sel -t -m "object" -v "Alt_Name"`
    Object_Type=`echo $XML  | xmlstarlet sel -t -m "object" -v "Type"`
    Position_Angle=`echo $XML  | xmlstarlet sel -t -m "object" -v "Position_Angle"`
    Constellation=`echo $XML  | xmlstarlet sel -t -m "object" -v "Constellation"`

    if test "$Long_Name" != "$Name"; then
	Name_Display="${Long_Name} (${Name})"
    else
	Name_Display="${Name}"
    fi;

    if test -z "$Alt_Name"; then
	Alt_Name="--" # Use a dash for blank alternate names
    fi;

#     zoomed_in_size=`echo $maj_axis*10 | bc -l`
#     if test -z $zoomed_in_size -o $(echo "$zoomed_in_size <= 15" | bc -l) -eq 1; then
# 	zoomed_in_size=15
#     fi;
# #    intermediate=`echo $zoomed_in_size*6 | bc -l`
# #    zoomed_out=`echo $intermediate*4 | bc -l`
#     zoomed_out=2400 # 40 degrees on the height dimension
#     intermediate=`echo "e(( l($zoomed_in_size) + l($zoomed_out) )/2)" | bc -l` # Arithmetic mean of log(FOV)
#     echo "Zoomed in: " $zoomed_in_size
#     echo "Intermediate: " $intermediate
#     echo "Zoomed out: " $zoomed_out

    # Get sky map aspect ratio and convert FOVs to degrees

    skymap_aspect_ratio=`qdbus org.kde.kstars /KStars org.kde.kstars.getSkyMapDimensions | sed 's,x,/,' | bc -l`
    width=`qdbus org.kde.kstars /KStars org.kde.kstars.getSkyMapDimensions | sed 's,x.*$,,'`
    height=`qdbus org.kde.kstars /KStars org.kde.kstars.getSkyMapDimensions | sed 's,^.*x,,'`
    FOV=`echo "20*${skymap_aspect_ratio}" | bc -l`

    if [ $DEBUG ]; then echo "Capturing sky map with FOV = " $FOV; fi;

    # Export all three sky images
    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object"
    qdbus org.kde.kstars /KStars org.kde.kstars.setApproxFOV ${FOV}
#    echo "qdbus org.kde.kstars /KStars org.kde.kstars.exportImage `pwd`/${BUILD_DIR}/${object_underscored}_skychart.svg"
    qdbus org.kde.kstars /KStars org.kde.kstars.exportImage `pwd`/${BUILD_DIR}/${object_underscored}_skychart.svg
    
    if [ $DEBUG ]; then echo "Obtained skychart. Converting to PDF"; fi;

    skychart_PDF=${BUILD_DIR}/${object_underscored}_skychart.pdf
    inkscape -T -A $skychart_PDF ${BUILD_DIR}/${object_underscored}_skychart.svg

    # Get DSS image
    DSS_URL=`qdbus org.kde.kstars /KStars org.kde.kstars.getDSSURL "$object"`
    DSS_size_string=`echo $DSS_URL | sed "s/^.*&h=\([0-9\.]*\)&w=\([0-9\.]*\)&.*$/$\2' \\\\\times \1'$/"`
    DSS=${BUILD_DIR}/${object_underscored}_dss.png
    if [ ! -f $DSS ]; then
	if [ $DEBUG ]; then echo "Obtaining DSS image. Query URL: " $DSS_URL; fi;
	wget $DSS_URL -O ${BUILD_DIR}/${object_underscored}_dss.gif
	convert -negate ${BUILD_DIR}/${object_underscored}_dss.gif $DSS
	rm ${BUILD_DIR}/${object_underscored}_dss.gif
    else
	if [ $DEBUG ]; then echo "DSS image found at ${DSS}. Assuming that we can use that."; fi;
    fi;

    # Set up the LaTeX -- TODO: This is bad; we have to find a better way to write this.
    if [ $DEBUG ]; then echo "Generating TeX for the object's logging form"; fi;
    texfile=${BUILD_DIR}/${object_underscored}.tex
    echo "" > $texfile
    echo "
\section*{\center \Huge ${Name_Display}}
\label{$object_underscored}
\vspace{-2pt}
\begin{center}
\Large ${Object_Type} in ${Constellation} \\
\end{center}
\vspace{2pt}

\begin{center}
{\large Data}
\\\\
\vspace{5pt}
\begin{tabular}{| l | c || l | c |}
\hline
Right Ascension (current) & $ ${RA_HMS} $ & Declination (current) & $ ${Dec_DMS} $ \\\\
Right Ascension (J2000.0) & $ ${RA_HMS_J2000} $ & Declination (J2000.0) & $ ${Dec_DMS_J2000} $ \\\\
\hline
Size & $ ${maj_axis}' \times ${min_axis}' $ & Position Angle & $ ${Position_Angle} \\degree $ \\\\
Magnitude & $ ${mag} $ & Other Designation & ${Alt_Name} \\\\
\hline
\end{tabular}
\end{center}

\vspace{3pt}
{\small ${object_description_with_prefix}} \\\\
\vspace{2pt}

\begin{figure}[h!]
\centering
\begin{subfigure}[h!]{0.5\textwidth}
\centering
\includegraphics[width=\textwidth]{${skychart_PDF}}
\caption{Sky Chart}
\end{subfigure}
~
\begin{subfigure}[h!]{0.3\textwidth}
\centering
\includegraphics[width=\textwidth]{$DSS}
\caption{DSS Image (${DSS_size_string})}
\end{subfigure}

\end{figure}

\\\\

\begin{figure*}[h!]
\centering
\includegraphics[width=0.8\textwidth]{Logging-Form.pdf}
\end{figure*}

" >> $texfile
    
    if [ -n "$LOGO_FILE" -a -f "$LOGO_FILE" ]; then
	if [ $DEBUG ]; then echo "Writing TeX to place logo from ${LOGO_FILE}"; fi;
	echo "
\begin{textblock}{${LOGO_SIZE}}(0.8,2.0)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{$LOGO_FILE}
\end{figure*}
\end{minipage}
\end{textblock}

" >> $texfile
    fi;


    if [[ "${object_observability}" == *C* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place city icon from ${CITY_ICON} and telescope icon from ${TELESCOPE_ICON}"; fi;
	echo "
\begin{textblock}{0.5}(6.65,2.15)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${CITY_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}

\begin{textblock}{0.2}(7.22,2.30)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${TELESCOPE_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}
" >> $texfile;
    fi;

    if [[ "${object_observability}" == *B* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place binocular icon from ${BINOCULAR_ICON}"; fi;
	echo "
\begin{textblock}{0.5}(6.65,2.525)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${BINOCULAR_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}

" >> $texfile;
    fi;

    if [[ "${object_observability}" == *CB* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place binocular icon from ${BINOCULAR_ICON} next to the city icon"; fi;
	echo "
\begin{textblock}{0.20}(7.22,2.10)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${BINOCULAR_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}

" >> $texfile;
    fi;

#    cd $BUILD_DIR
#    pdflatex -interaction nonstopmode $texfile
#    cd -
    
    list="$list ${object_underscored}.pdf"
    
    # if [[ $constellations != *${Constellation}* ]]; then # Create a list of unique constellations
    # 	constellations_unsort="${constellations} ${Constellation}";
    # fi;
    
    # if [[ $types != *${ObjecT_Type}* ]]; then # Create a list of unique constellations
    # 	types_unsort="${types} ${Object_Type}";
    # fi;
    
    if [ $DEBUG ]; then echo "Concatenating rendered TeX into Objects.tex file in ${BUILD_DIR} directory"; fi;
    echo -e "\n%%%%%%%%%%%%%%%%%%%%%% ${object} %%%%%%%%%%%%%%%%%%%%%%" >> ${BUILD_DIR}/Objects.tex
    echo -e "\n\\\\clearpage" >> ${BUILD_DIR}/Objects.tex
    cat $texfile >> ${BUILD_DIR}/Objects.tex
    echo '{\footnotesize \center This content is protected by Copyrights. See the~\nameref{Legal} chapter of this document for details.}' >> ${BUILD_DIR}/Objects.tex
    
    if [ $DEBUG ]; then echo "Writing entry into ConstType.txt file for generation of index by constellation and type"; fi;
    echo "${Constellation}|${Object_Type}|${object}|${Name_Display}" >> ${BUILD_DIR}/ConstType.txt

    if [ $DEBUG ]; then echo "Writing entry into Checklist file"; fi;
    echo "${Name_Display} & ${Object_Type} & ${Constellation} & $ ${mag} $ & $ ${maj_axis}' \times ${min_axis}' $ & \pageref{$object_underscored} &  & \\\\ \hline" >> ${BUILD_DIR}/Checklist.tex

    # If we are overflowing a page (~ 65 entries) of the checklist, close the table, clearpage, and start afresh on the next page.
    object_count=$(($object_count+1))
    checklist_count=$(($checklist_count+1))
    if [ $DEBUG ]; then echo "Object count: ${object_count}; Checklist count: ${checklist_count}; Total objects: ${total_objects}"; fi;
    if [ ${checklist_count} -ge 65 -a ${object_count} -lt ${total_objects} ]; then
	if [ $DEBUG ]; then echo "Hit per-page limit for checklist before we're done. Creating a new page."; fi;
	echo "\end{tabular}
}
\clearpage
\resizebox{\textwidth}{!}{
\centering
%\newcolumntype{C}{>{\centering\arraybackslash} m{0.1\textwidth}}
\begin{tabular}{|c|c|c|c|c|c||c|c|}
\hline
Object & Type & Constellation & Mag. & Size & Page & Obs. Date & Second Obs.\\\\
\hline
\hline
" >> ${BUILD_DIR}/Checklist.tex
	checklist_count=0;
    fi;

echo "Object-wise Progress: " `echo "100*${object_count}/${total_objects}" | bc`"%";
    
done <$OBJECT_LIST;

echo "\end{tabular}
}" >> ${BUILD_DIR}/Checklist.tex

# Generate sorted lists of constellations and types
if [ $DEBUG ]; then echo "Making lists of constellations and types in Constellations.txt and Types.txt."; fi;
cat ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $1 }' | sort | uniq > ${BUILD_DIR}/Constellations.txt
cat ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $2 }' | sort | uniq > ${BUILD_DIR}/Types.txt

# Generate object list by constellation
while read Constellation; do
    if [ $DEBUG ]; then echo "Writing constellation-wise index for constellation ${Constellation}"; fi;
    echo "\subsection*{${Constellation}}" >> ${BUILD_DIR}/ObjectsByConstellation.tex
    grep "^${Constellation}|" ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $NF "\\\\" }' | sort >> ${BUILD_DIR}/ObjectsByConstellation.tex
done < ${BUILD_DIR}/Constellations.txt;

# Generate object list by type
while read Type; do
    if [ $DEBUG ]; then echo "Writing object-type-wise index for object type ${Type}"; fi;
    echo "\subsection*{${Type}}" >> ${BUILD_DIR}/ObjectsByType.tex
    grep "^[^|]*|${Type}|" ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $NF "\\\\" }' | sort >> ${BUILD_DIR}/ObjectsByType.tex
done < ${BUILD_DIR}/Types.txt;

if [ $DEBUG ]; then echo "Script finished!"; fi;

