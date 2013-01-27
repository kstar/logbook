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

if [ -z $1 ]; then

    echo "ERROR: No project name supplied. The project name is the title of the logbook."
    echo "Invokation: ./generate-logbook.sh <project name> [object list file] [\"build\" directory]"
    exit 1;
fi;

if [ -z $2 ]; then
    OBJECT_LIST='objectlist.txt'
else
    OBJECT_LIST=$2
fi;

if [ $DEBUG ]; then echo $OBJECT_LIST; fi;

if [ -z $3 ]; then
    BUILD_DIR='build'
else
    BUILD_DIR=$3
fi;

if [ ! -f $OBJECT_LIST ]; then
    echo "Object list file " $OBJECT_LIST " not found."
    echo "Invokation: ./generate-logbook.sh <project name> [object list file] [\"build\" directory]"
    exit 1;
fi;

mkdir -p $BUILD_DIR; # Create the "build" directory

list='' # List of objects for final processing

echo "" > ${BUILD_DIR}/Objects.tex
echo "" > ${BUILD_DIR}/ConstType.txt
echo "" > ${BUILD_DIR}/ObjectsByType.tex
echo "" > ${BUILD_DIR}/ObjectsByConstellation.tex
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
    
    skychart_PDF=${BUILD_DIR}/${object_underscored}_skychart.pdf
    inkscape -T -A $skychart_PDF ${BUILD_DIR}/${object_underscored}_skychart.svg

    # Get DSS image
    DSS_URL=`qdbus org.kde.kstars /KStars org.kde.kstars.getDSSURL "$object"`
    DSS_size_string=`echo $DSS_URL | sed "s/^.*&h=\([0-9\.]*\)&w=\([0-9\.]*\)&.*$/$\2' \\\\\times \1'$/"`
    DSS=${BUILD_DIR}/${object_underscored}_dss.png
    if [ ! -f $DSS ]; then
	wget $DSS_URL -O ${BUILD_DIR}/${object_underscored}_dss.gif
	convert -negate ${BUILD_DIR}/${object_underscored}_dss.gif $DSS
	rm ${BUILD_DIR}/${object_underscored}_dss.gif
    fi;

    # Set up the LaTeX -- TODO: This is bad; we have to find a better way to write this.
    texfile=${BUILD_DIR}/${object_underscored}.tex
    echo "" > $texfile
    echo "
\section*{\center \Huge ${Name_Display}}
\begin{center}
\Large ${Object_Type} in ${Constellation} \\
\end{center}
\vspace{5pt}

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

\vspace{5pt}
${object_description_with_prefix}
\vspace{5pt}

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

\begin{figure}[h!]
\centering
\includegraphics[width=0.8\textwidth]{Logging-Form.pdf}
\end{figure}

" >> $texfile

if [[ "${object_observability}" == *C* ]]; then
    echo "
\begin{textblock}{0.5}(6.5,1.9)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure}[h!]
\includegraphics[width=\textwidth]{city.pdf}
\end{figure}
\end{minipage}
\end{textblock}

" >> $texfile;
fi;

if [[ "${object_observability}" == *[^C]B* ]]; then
    echo "
\begin{textblock}{0.5}(6.5,2.3)
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure}[h!]
\includegraphics[width=\textwidth]{binoculars.pdf}
\end{figure}
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
    
    echo -e "\n%%%%%%%%%%%%%%%%%%%%%% ${object} %%%%%%%%%%%%%%%%%%%%%%" >> ${BUILD_DIR}/Objects.tex
    cat $texfile >> ${BUILD_DIR}/Objects.tex
    
    echo "${Constellation}|${Type}|${object}|${Name_Display}" >> ${BUILD_DIR}/ConstType.txt

done <$OBJECT_LIST;

# Generate sorted lists of constellations and types
cat ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $1 }' | sort | uniq > ${BUILD_DIR}/Constellations.txt
cat ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $2 }' | sort | uniq > ${BUILD_DIR}/Types.txt

# Generate object list by constellation
for Constellation in `cat ${BUILD_DIR}/Constellations.txt`; do
    echo "\subsection*{${Constellation}}" >> ${BUILD_DIR}/ObjectsByConstellation.tex
    grep "^${Constellation}|" ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $NF "\\\\" }' | sort >> ${BUILD_DIR}/ObjectsByConstellation.tex
done;

# Generate object list by type
for Type in `cat ${BUILD_DIR}/Types.txt`; do
    echo "\subsection*{${Type}}" >> ${BUILD_DIR}/ObjectsByType.tex
    grep "^[^|]*|${Type}|" ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $NF "\\\\" }' | sort >> ${BUILD_DIR}/ObjectsByType.tex
done;

