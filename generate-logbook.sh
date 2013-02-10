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

##### Variables in the configuration file supplied. Default values in parantheses.

### Mandatory
# PROJECT_NAME -- The title of the book (eg: The Messier Observer's Handbook)
# OBJECTLIST_FILE -- A file containing a list of objects that KStars knows about. Optionally, separated by |, fields containing a brief description of the object, and observability codes
# PREFACE_FILE -- A TeX file containing the preface of the logbook

### Generic
# DEBUG (unset) -- if set, enables verbose debugging output
# NO_DELETE_UNUSED (unset) -- if set, does not delete temporary sky chart SVG and DSS gif files
# NO_REUSE_EXISTING_SKYCHART (unset) -- if set, does not reuse existing skychart images, and generates new ones instead
# NO_REUSE_EXISTING_DSS (unset) -- if set, does not reuse existing DSS images, and downloads new ones instead
# DSS_RESIZE (unset) -- can be set to a size (eg: 1024) argument understood by the -resize option of ImageMagick's convert utility, so as to save space by downscaling DSS imagery.

### Controlling the form generation
# SINGLE_PAGE (unset) -- if set, enables single-page logging forms
# FOV_ZOOMED_IN (unset) -- used only in two-page mode. Sets the zoomed-in FOV. If unset, a dynamic FOV of 10 * (object's major axis is used)
# FOV_ZOOMED_OUT (40) -- used only in two-page mode. Sets the zoomed-out FOV. If unset, a default of 40 degrees is used
# FOV_INTERMEDIATE (unset) -- used only in two-page mode. Sets the intermediate FOV. If unset, the logarithmic average of the zoomed-in and zoomed-out FOVs is used.
# APPROX_FOV (20) -- used only in single-page mode. Sets the FOV of the skychart
# SKYCHART_RATIO (0.6) -- used only in single-page mode. Sets the ratio of space used by the sky chart to the total space used by the DSS image and the sky chart.

### Overlays
# LOGO_SIZE (0.7) -- size of an optional logo overlay in inches
# LOGO_FILE (unset) -- file containing an optional logo to render on each object's front page
# BINOCULAR_ICON (binoculars.pdf) -- a file containing clipart of a binocular to render for binocular-observable objects
# TELESCOPE_ICON (kstars.pdf) -- a file containing clipart of a telescope to render for telescope-observable objects
# EYE_ICON (eye.pdf) -- a file containing clipart indicative of naked eye observability
# LOGFORM_FILE (Logging-Form.pdf) -- a file containing the logging form
# CITY_ICON (city.pdf) -- a file containing the city icon

##### Default values for various settable parameters.
## Unsettables
unset LOGO_FILE
unset DSS_RESIZE
unset NO_DELETE_UNUSED
unset NO_REUSE_EXISTING_DSS
unset NO_REUSE_EXISTING_SKYCHART
unset SINGLE_PAGE
unset FOV_ZOOMED_IN
unset FOV_INTERMEDIATE
unset FOV_ZOOMED_OUT
unset APPROX_FOV

## Debug mode (verbosity)
unset DEBUG

## Star chart and DSS imagery settings
SKYCHART_RATIO=0.6 ## Used _only_ with single page mode. Percentage of the space that is allocated to the Sky Chart.

## Default values for files and properties for various icons and overlays. To override, redefine in the config file
LOGO_SIZE=0.7 # Logo size in inches.
CITY_ICON="city.pdf"
BINOCULAR_ICON="binoculars.pdf"
TELESCOPE_ICON="kstars.pdf"
EYE_ICON="eye.pdf"
LOGFORM_FILE="Logging-Form.pdf"
MAIN_TEX_FILE="Main.tex"

##### Read command line arguments. Check if we have been supplied with a configuration file, exporting various variables.
if [ -z "$1" ]; then
    echo "ERROR: No configuration file supplied. Please see the README for details on how to create one."
    echo "Invokation: ./generate-logbook.sh <configuration shell script> [\"build\" directory]"
    echo "Note that the build directory *MUST BE* relative to the current directory. The default value is 'build'"
    exit 1;
else
    CONFIG_FILE=$1
fi;

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration script file " $CONFIG_FILE " not found. Please supply a valid filename."
    echo "Invokation: ./generate-logbook.sh <configuration shell script> [\"build\" directory]"
    echo "Note that the build directory *MUST BE* relative to the current directory. The default value is 'build'"
    exit 1;
fi;

if [ -z "$2" ]; then
    BUILD_DIR='build'
else
    BUILD_DIR=$4
fi;

if [ $DEBUG ]; then echo "Using the directory ${BUILD_DIR} for temporary files and for caching DSS images. The directory will be created if it does not already exist."; fi;
mkdir -p $BUILD_DIR; # Create the "build" directory

##### Source configuration file and check if essential variables are defined and valid
if [ $DEBUG ]; then echo "Sourcing config file: ${CONFIG_FILE}"; fi;
source $CONFIG_FILE;

if [ -z "$PROJECT_NAME" ]; then
    echo "ERROR: Project Name is blank. Please set at least the bare minimum required parameters. See the README for more."
    exit 1;
fi;

if [ ! -f "$OBJECTLIST_FILE" ]; then
    echo "ERROR: Object list file " $OBJECTLIST_FILE " not found. Please set a valid file."
    exit 1;
fi;

if [ ! -f "$PREFACE_FILE" ]; then
    echo "ERROR: LaTeX Preface file \"$2\" is not a valid file. Please set a valid file."
    exit 1;
fi;

if [ $DEBUG ]; then echo "Object list file: ${OBJECTLIST_FILE}. Preface file: ${PREFACE_FILE}. Project Name: ${PROJECT_NAME}"; fi;

if [ ! -f "$LOGO_FILE" ]; then
    echo "Warning: Not a valid file: " $LOGO_FILE
    echo "Will not use any logo"
    LOGO_FILE=""
fi;

##### Some derived quantities that don't change
TOTAL_OBJECTS=`cat ${OBJECTLIST_FILE} | wc -l` # Total number of objects
PREFACE_FILE_WITHOUT_EXTENSION=${PREFACE_FILE%.[tT][eE][xX]}
SKYCHART_SIZE=`echo "${SKYCHART_RATIO}*0.8" | bc -l`
DSS_SIZE=`echo "(1-${SKYCHART_RATIO})*0.8" | bc -l`

##### Initialize various counters and "loop" variables
list='' # List of objects for final processing
checklist_count=20 # Count for objects in checklist to prevent overflowing the page. Start from 10 since the first page has a chapter title etc.
object_count=0 # Count of the number of objects, that doesn't reset

##### Initialize the content of various files
echo "" > ${BUILD_DIR}/Objects.tex
echo "" > ${BUILD_DIR}/ConstType.txt
echo "" > ${BUILD_DIR}/ObjectsByType.tex
echo "" > ${BUILD_DIR}/ObjectsByConstellation.tex

echo "\resizebox{\textwidth}{!}{
\centering
%\newcolumntype{C}{>{\centering\arraybackslash} m{0.1\textwidth}}
\begin{tabular}{|r|c|c|c|c|c|c||c|c|}
\hline
Sl.No. & Object & Type & Constellation & Mag. & Size & Page & Obs. Date & Second Obs.\\\\
\hline
\hline
" > ${BUILD_DIR}/Checklist.tex

echo "\title{\Huge ${PROJECT_NAME}}
\maketitle

\frontmatter
\tableofcontents

\chapter*{Preface}

\input{$PREFACE_FILE_WITHOUT_EXTENSION}" > ${BUILD_DIR}/FrontMatter.tex

##### Main loop -- loops over objects in the list
while read object_list_line; do

    if [ $DEBUG ]; then echo "Processing line: " $object_list_line; fi;

    #### Retrieve and set up object data in variables.
    object=`echo $object_list_line | awk -F'|' '{ print $1 }'` # Retrieve the name of the object from the list
    object_description=`echo $object_list_line | awk -F'|' '{ print $2 }' | sed 's/___REPLACE_PIPE___/|/g'` # Retrieve a description of the object. The sed is a hack to be able to use \verb|...| (verbatim)
    object_observability=`echo $object_list_line | awk -F'|' '{ print $3 }'` # Retrieve an observability string indicating whether the object is city / binocular observable

    if [ -n "$object_description" ]; then
	object_description_with_prefix="\textbf{Description:} $object_description";
    else
	object_description_with_prefix=""
    fi;

    if [ $DEBUG ]; then echo "Object: " $object; fi;

    object_underscored=`echo $object | sed 's/ /_/g'`; # An underscored copy of the object for use in file names etc

    if [ $DEBUG ]; then echo "Underscored: " $object_underscored; fi;

    # Look towards object before getting XML so that current RA / Dec are updated.
    if [ $DEBUG ]; then echo "Steering KStars to object ${object}. Make sure it exists in KStars as there is no error checking."; fi;
    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object"
    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object" # KStars has some weird bug of landing slightly off from the object. Calling this again is a hack to get right on the object.
    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object" # KStars has some weird bug of landing slightly off from the object. Calling this again is a hack to get right on the obj

    XML=`qdbus org.kde.kstars /KStars org.kde.kstars.getObjectDataXML "$object"`
    maj_axis=`echo $XML | xmlstarlet sel -t -m "object" -v "Major_Axis"`
    min_axis=`echo $XML | xmlstarlet sel -t -m "object" -v "Minor_Axis"`
    RA_HMS=`echo $XML | xmlstarlet sel -t -m "object" -v "RA_HMS" | sed 's/\([hms]\)/^{\\\mathrm{\1}\\\,}/g'`
    RA_HMS_J2000=`echo $XML | xmlstarlet sel -t -m "object" -v "RA_J2000_HMS" | sed 's/\([hms]\)/^{\\\mathrm{\1}\\\\\,}/g'`
    Dec_DMS=`echo $XML | xmlstarlet sel -t -m "object" -v "Dec_DMS" | sed "s/°/\\\\\circdegree\\\\\,/;s/'/'\\\\\,/;s/\"/''\\\\\,/"` # SED needed because LaTeX doesn't like the degree symbol
    Dec_DMS_J2000=`echo $XML | xmlstarlet sel -t -m "object" -v "Dec_J2000_DMS" | sed "s/°/\\\\\circdegree\\\\\,/;s/'/'\\\\\,/;s/\"/''\\\\\,/"` # SED needed because LaTeX doesn't like the degree symbol
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

    # Mirach's Ghost gets its own special hack to remove "(Galaxy not found :)" :D
    Name_Display=`echo ${Name_Display} | sed 's/ (Galaxy not found :)//'`

    if test -z "$Alt_Name"; then
	Alt_Name="--" # Use a dash for blank alternate names
    fi;

    # skymap_aspect_ratio=`qdbus org.kde.kstars /KStars org.kde.kstars.getSkyMapDimensions | sed 's,x,/,' | bc -l`
    # width=`qdbus org.kde.kstars /KStars org.kde.kstars.getSkyMapDimensions | sed 's,x.*$,,'`
    # height=`qdbus org.kde.kstars /KStars org.kde.kstars.getSkyMapDimensions | sed 's,^.*x,,'`

    #### Get DSS image
    DSS_URL=`qdbus org.kde.kstars /KStars org.kde.kstars.getDSSURL "$object"`
    DSS_size_string=`echo $DSS_URL | sed "s/^.*&h=\([0-9\.]*\)&w=\([0-9\.]*\)&.*$/$\2' \\\\\times \1'$/"`
    DSS=${BUILD_DIR}/${object_underscored}_dss.png
    DSS_band="B"
    if [ ! -f "${DSS}" -o "${NO_REUSE_EXISTING_DSS}" ]; then
	if [ $DEBUG ]; then echo "Obtaining DSS image. Query URL: " $DSS_URL; fi;

	wget $DSS_URL -O ${BUILD_DIR}/${object_underscored}_dss.gif 
	ftype=`file "${BUILD_DIR}/${object_underscored}_dss.gif"`
	if [[ $ftype != *GIF* ]]; then
	    if [ $DEBUG ]; then echo "Failed on Blue. Trying to obtain a red plate"; fi;
	    # We failed to download. Try Red plates
	    wget `echo "$DSS_URL" | sed 's/_blue/_red/'` -O ${BUILD_DIR}/${object_underscored}_dss.gif 
	    ftype=`file "${BUILD_DIR}/${object_underscored}_dss.gif"`
	    DSS_band="R"
	    if [[ $ftype != *GIF* ]]; then
		if [ $DEBUG ]; then echo "Failed on Red. Trying to obtain an IR plate"; fi;
		# Even the red plates failed. Try IR
		wget `echo "$DSS_URL" | sed 's/_blue/_ir/'` -O ${BUILD_DIR}/${object_underscored}_dss.gif 
		ftype=`file "${BUILD_DIR}/${object_underscored}_dss.gif"`
		DSS_band="I"
	    fi;
	fi;

	## TODO: Add the band (IR / Blue / Red) of the DSS image to the caption

	if [[ $ftype != *GIF* ]]; then
	    echo "Warning: Could not download DSS image. Will proceed without one";
	    DSS_band="?"
	    DSS_size_string="?"
	    rm -f ${BUILD_DIR}/${object_underscored}_dss.gif # Make sure it's not re-used in future
	    rm -f ${BUILD_DIR}/${object_underscored}_dss_metadata.txt
	else
	    echo "(${DSS_band}, ${DSS_size_string})" > ${BUILD_DIR}/${object_underscored}_dss_metadata.txt
	fi;

	if [ $DSS_RESIZE ]; then
	    convert -negate ${BUILD_DIR}/${object_underscored}_dss.gif -resize ${DSS_RESIZE} $DSS
	else
	    convert -negate ${BUILD_DIR}/${object_underscored}_dss.gif $DSS
	fi;

	if [ ! ${NO_DELETE_UNUSED} ]; then
	    rm -f ${BUILD_DIR}/${object_underscored}_dss.gif
	fi;
    else
	if [ $DEBUG ]; then echo "DSS image found at ${DSS}. Assuming that we can use that."; fi;
    fi;

    if [ -f ${BUILD_DIR}/${object_underscored}_dss_metadata.txt ]; then
	DSS_metadata=`cat "${BUILD_DIR}/${object_underscored}_dss_metadata.txt"`
    else
	DSS_metadata="(details unknown)"
    fi;

    #### Calculate FOVs and Acquire sky maps
#    if [ $DEBUG ]; then echo "Steering KStars to object ${object}. Make sure it exists in KStars as there is no error checking."; fi;
#    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object"
#    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object" # KStars has some weird bug of landing slightly off from the object. Calling this again is a hack to get right on the object.

    if [ ! ${SINGLE_PAGE} ]; then
	## Filenames to carry the 3 skycharts
	zoomed_out_skychart=`pwd`/${BUILD_DIR}/${object_underscored}_skychart_zoomed_out.svg
	intermediate_skychart=`pwd`/${BUILD_DIR}/${object_underscored}_skychart_intermediate.svg
	zoomed_in_skychart=`pwd`/${BUILD_DIR}/${object_underscored}_skychart_zoomed_in.svg

	zoomed_out_skychart_PDF=`pwd`/${BUILD_DIR}/${object_underscored}_skychart_zoomed_out.pdf
	intermediate_skychart_PDF=`pwd`/${BUILD_DIR}/${object_underscored}_skychart_intermediate.pdf
	zoomed_in_skychart_PDF=`pwd`/${BUILD_DIR}/${object_underscored}_skychart_zoomed_in.pdf

        ## FOV sizes, in degrees for multi-page mode
	if [ -n "${FOV_ZOOMED_IN}" ]; then
	    fov_zoomed_in=${FOV_ZOOMED_IN}
	else
	    fov_zoomed_in=`echo $maj_axis/6.0 | bc -l` # 10 x the major axis, in degrees
	    if [ -z $fov_zoomed_in -o $(echo "$fov_zoomed_in <= 0.25" | bc -l) -eq 1 ]; then
		fov_zoomed_in=0.25
	    fi;
	fi;
	
	if [ -n "${FOV_ZOOMED_OUT}" ]; then
	    fov_zoomed_out=${FOV_ZOOMED_OUT}
	else
	    fov_zoomed_out=40
	fi;
	
	if [ -n "${FOV_INTERMEDIATE}" ]; then
	    fov_intermediate=${FOV_INTERMEDIATE}
	else
	    fov_intermediate=`echo "e(( l($fov_zoomed_in) + l($fov_zoomed_out) )/2)" | bc -l` # Arithmetic mean of log(FOV)
	fi;
	
	if [ $DEBUG ]; then echo "FOVs in Degrees. Zoomed-in: ${fov_zoomed_in}; Intermediate: ${fov_intermediate}; Zoomed-out: ${fov_zoomed_out}"; fi;

	if [ -f "$zoomed_in_skychart_PDF" -a ! "${NO_REUSE_EXISTING_SKYCHART}" ]; then
	    echo "Warning: Using existing zoomed in sky chart for object ${object} -- ${zoomed_in_skychart_PDF}. If you changed FOVs, please delete the files.";
	else
	    if [ $DEBUG ]; then echo "Capturing zoomed in skychart for ${object}. FOV = ${fov_zoomed_in}"; fi;
	    qdbus org.kde.kstars /KStars org.kde.kstars.setApproxFOV ${fov_zoomed_in}
	    qdbus org.kde.kstars /KStars org.kde.kstars.exportImage "${zoomed_in_skychart}"
	    inkscape -T -A ${zoomed_in_skychart_PDF} ${zoomed_in_skychart}
	fi;


	if [ -f "$intermediate_skychart_PDF" -a ! "${NO_REUSE_EXISTING_SKYCHART}" ]; then
	    echo "Warning: Using existing intermediate sky chart for object ${object} -- ${intermediate_skychart_PDF}. If you changed FOVs, please delete the files.";
	else
	    if [ $DEBUG ]; then echo "Capturing intermediate skychart for ${object}. FOV = ${fov_intermediate}"; fi;
	    qdbus org.kde.kstars /KStars org.kde.kstars.setApproxFOV ${fov_intermediate}
	    qdbus org.kde.kstars /KStars org.kde.kstars.exportImage "${intermediate_skychart}"
	    inkscape -T -A ${intermediate_skychart_PDF} ${intermediate_skychart}
	fi;


	if [ -f "$zoomed_out_skychart_PDF" -a ! "${NO_REUSE_EXISTING_SKYCHART}" ]; then
	    echo "Warning: Using existing zoomed out sky chart for object ${object} -- ${zoomed_out_skychart_PDF}. If you changed FOVs, please delete the files.";
	else
	    if [ $DEBUG ]; then echo "Capturing zoomed out skychart for ${object}. FOV = ${fov_zoomed_out}"; fi;
	    qdbus org.kde.kstars /KStars org.kde.kstars.setApproxFOV ${fov_zoomed_out}
	    qdbus org.kde.kstars /KStars org.kde.kstars.exportImage "${zoomed_out_skychart}"
	    inkscape -T -A ${zoomed_out_skychart_PDF} ${zoomed_out_skychart}
	fi;

	if [ ! ${NO_DELETE_UNUSED} ]; then
	    if [ $DEBUG ]; then echo "Deleting unused SVG files."; fi;
	    rm -f "${zoomed_out_skychart}" "${zoomed_in_skychart}" "${intermediate_skychart}"
	else
	    if [ $DEBUG ]; then echo "Keeping unused SVG files since NO_DELETE_UNUSED was defined."; fi;
	fi;

    else
        ## FOV sizes, in degrees, for single-page mode
	skychart=`pwd`/${BUILD_DIR}/${object_underscored}_skychart.svg
	skychart_PDF=`pwd`/${BUILD_DIR}/${object_underscored}_skychart.pdf

	if [ ${APPROX_FOV} ]; then
	    fov=${APPROX_FOV}
	else
	    fov=20;
	fi;

	if [ -f "${skychart_PDF}" -a ! "${NO_REUSE_EXISTING_SKYCHART}" ]; then
	    echo "Warning: Using existing sky chart for object ${object} -- ${skychart_PDF}. If you changed FOVs, please delete the files.";
	else
	    if [ $DEBUG ]; then echo "Capturing skychart for ${object}. FOV = ${fov}"; fi;
	    qdbus org.kde.kstars /KStars org.kde.kstars.setApproxFOV "${fov}"
	    qdbus org.kde.kstars /KStars org.kde.kstars.exportImage "${skychart}"
	    inkscape -T -A ${skychart_PDF} ${skychart}
	fi;

	if [ ! ${NO_DELETE_UNUSED} ]; then
	    if [ $DEBUG ]; then echo "Deleting unused SVG file."; fi;
	    rm -f "${skychart}"
	else
	    if [ $DEBUG ]; then echo "Keeping unused SVG file since NO_DELETE_UNUSED was defined."; fi;
	fi;

    fi;
	    
    ##### Set up the observation pageLaTeX. FIXME: Is there a better way to write this?
    if [ $DEBUG ]; then echo "Generating TeX for the object's logging form"; fi;
    texfile=${BUILD_DIR}/${object_underscored}.tex
    echo "" > $texfile

    ### First write out the common parts -- title, subtitle, data table, and description.
    echo "
\section*{\center \Huge ${Name_Display}}
\vspace{-2pt}
\begin{center}
\Large ${Object_Type} in ${Constellation} \\\\
\end{center}
\ifletterpaper
\vspace{-10pt}
\else
\vspace{2pt}
\fi

\begin{center}
\label{$object_underscored}
{\large Data}
\\\\
\ifletterpaper
\vspace{2pt}
\else
\vspace{5pt}
\fi
\begin{tabular}{| l | c || l | c |}
\hline
Right Ascension (current) & $ ${RA_HMS} $ & Declination (current) & $ ${Dec_DMS} $ \\\\
Right Ascension (J2000.0) & $ ${RA_HMS_J2000} $ & Declination (J2000.0) & $ ${Dec_DMS_J2000} $ \\\\
\hline
Size & $ ${maj_axis}' \times ${min_axis}' $ & Position Angle & $ ${Position_Angle} \\circdegree $ \\\\
Magnitude & $ ${mag} $ & Other Designation & ${Alt_Name} \\\\
\hline
\end{tabular}
\end{center}

\vspace{3pt}
{\small ${object_description_with_prefix}} \\\\
\ifletterpaper
\vspace{-1pt}
\else
\vspace{2pt}
\fi

" >> $texfile

    if [ ${SINGLE_PAGE} ]; then
        ### In single page mode, put the single skychart and the DSS image side-by-side
	if [ $DEBUG ]; then echo "Generating single page version"; fi;
	echo "
\begin{figure*}[h!]
\centering
\begin{subfigure}[h!]{${SKYCHART_SIZE}\textwidth}
\centering
\includegraphics[width=\textwidth]{${skychart_PDF}}
\caption*{Sky Chart}
\end{subfigure}
~
\begin{subfigure}[h!]{${DSS_SIZE}\textwidth}
\centering
\includegraphics[width=\textwidth]{$DSS}
\caption*{DSS Image ${DSS_metadata}}
\end{subfigure}

\end{figure*}

\\\\ " >> $texfile

	### Put in the logging form in the remaining space
echo "
\begin{figure*}[h!]
\centering
\includegraphics[width=0.85\textwidth,height=0.35\textheight,keepaspectratio]{${LOGFORM_FILE}}
\end{figure*}
" >> $texfile

    else
	### For multi-page mode, just write the first page now
	if [ $DEBUG ]; then echo "Generating two-page version"; fi;

        ### In multi-page mode, put the lower two zoom levels side-by-side
	echo "
\begin{figure*}[h!]
\centering
\begin{subfigure}[h!]{0.4\textwidth}
\centering
\includegraphics[width=\textwidth]{${zoomed_out_skychart_PDF}}
\caption*{Wide-field chart}
\end{subfigure}
~
\begin{subfigure}[h!]{0.4\textwidth}
\centering
\includegraphics[width=\textwidth]{${intermediate_skychart_PDF}}
\caption*{Intermediate chart}
\end{subfigure}

\end{figure*}

\vspace{2pt}
" >> $texfile

        ### Then put the wide-field chart filling the rest of the page
	echo "
\begin{figure*}[h!]
\centering
\ifletterpaper
\includegraphics[width=0.9\textwidth,height=0.3\textheight,keepaspectratio]{${zoomed_in_skychart_PDF}}
\else
\includegraphics[width=0.9\textwidth,height=0.35\textheight,keepaspectratio]{${zoomed_in_skychart_PDF}}
\fi
\caption*{Zoomed-in chart}
\end{figure*}" >> $texfile

	### We still have the second page to write, but we take a break here to put the overlays on the front page.
    fi;


    #### Draw the overlay figures -- a logo, if supplied; city, telescopes, binocular icons for indicating observability

    ## If a logo file is supplied, render it. TODO: Make the position specifiable
    if [ -n "$LOGO_FILE" -a -f "$LOGO_FILE" ]; then
	if [ $DEBUG ]; then echo "Writing TeX to place logo from ${LOGO_FILE}"; fi;
	echo "
\ifletterpaper
\begin{textblock}{${LOGO_SIZE}}(1.05,1.8)
\else
\begin{textblock}{${LOGO_SIZE}}(0.8,2.0)
\fi
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


    ## If the object is city-observable, render a city icon and a telescope icon on the top-right
    if [[ "${object_observability}" == *C* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place city icon from ${CITY_ICON} and telescope icon from ${TELESCOPE_ICON}"; fi;
	echo "
\ifletterpaper
\begin{textblock}{0.5}(6.9,1.95)
\else
\begin{textblock}{0.5}(6.65,2.15)
\fi
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${CITY_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}

\ifletterpaper
\begin{textblock}{0.2}(7.47,2.10)
\else
\begin{textblock}{0.2}(7.22,2.30)
\fi
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

    ## If the object is binocular-observable, render a binocular icon on the top-right
    if [[ "${object_observability}" == *B* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place binocular icon from ${BINOCULAR_ICON}"; fi;
	echo "
\ifletterpaper
\begin{textblock}{0.5}(6.9,2.325)
\else
\begin{textblock}{0.5}(6.65,2.525)
\fi
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

    ## If the object is observable in the city with binoculars, additionally render a small binocular icon next to the city icon
    if [[ "${object_observability}" == *CB* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place binocular icon from ${BINOCULAR_ICON} next to the city icon"; fi;
	echo "
\ifletterpaper
\begin{textblock}{0.20}(7.47,1.90)
\else
\begin{textblock}{0.20}(7.22,2.10)
\fi
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

    ## If the object is observable with the naked eye, render a the naked eye icon on the top-right
    if [[ "${object_observability}" == *N* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place eye icon from ${EYE_ICON}"; fi;
	echo "
\ifletterpaper
\begin{textblock}{0.5}(7.47,2.45)
\else
\begin{textblock}{0.5}(7.22,2.65)
\fi
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${EYE_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}

" >> $texfile;
    fi;

    ## If the object is observable in the city with the naked eye, additionally render a small eye icon next to the city icon
    if [[ "${object_observability}" == *CN* ]]; then
	if [ $DEBUG ]; then echo "Writing TeX to place eye icon from ${EYE_ICON} next to the city icon"; fi;
	echo "
\ifletterpaper
\begin{textblock}{0.20}(7.70,1.95)
\else
\begin{textblock}{0.20}(7.45,2.15)
\fi
\begin{minipage}{\textwidth}
\setlength{\parindent}{0pt}%
\setlength{\parskip}{0.1cm}%
\begin{figure*}[h!]
\includegraphics[width=\textwidth]{${EYE_ICON}}
\end{figure*}
\end{minipage}
\end{textblock}

" >> $texfile;
    fi;



    ## If we are writing 2 pages, we should resume writing the second page.
    if [ ! ${SINGLE_PAGE} ]; then
	### If we are writing 2 pages per object, we have to still write the next page.

	### So we first clear the page
	echo "\clearpage" >> $texfile

	### Put the DSS image, filling 0.9\textwidth or 0.5\textheight, whichever is smaller
	echo "
\ifletterpaper
 \vskip 15pt
 \\
\fi

\begin{figure*}[h!]
\centering
\ifletterpaper
\includegraphics[width=0.9\textwidth,height=0.42\textheight,keepaspectratio]{${DSS}}
\else
\includegraphics[width=0.9\textwidth,height=0.42\textheight,keepaspectratio]{${DSS}}
\fi
\caption*{DSS Image (${DSS_size_string})}
\end{figure*}" >> $texfile

	### Put the observing log form in the remaining space
	echo "
\begin{figure*}[h!]
\centering
\ifletterpaper
\includegraphics[width=0.9\textwidth,height=0.42\textheight,keepaspectratio]{${LOGFORM_FILE}}
\else
\includegraphics[width=0.9\textwidth,height=0.42\textheight,keepaspectratio]{${LOGFORM_FILE}}
\fi
\end{figure*}
" >> $texfile

    fi;

    #### Now we're done writing the TeX content into ${object_underscored}.tex. We need to put that into the larger Objects file.

    ## Append the object to the list of objects
    list="$list ${object_underscored}.pdf"
    
    if [ $DEBUG ]; then echo "Adding a \input for ${object_underscored}.tex into the Objects.tex file in the ${BUILD_DIR} directory"; fi;
    echo -e "\n%%%%%%%%%%%%%%%%%%%%%% ${object} %%%%%%%%%%%%%%%%%%%%%%" >> ${BUILD_DIR}/Objects.tex
    echo -e "\n\\\\clearpage" >> ${BUILD_DIR}/Objects.tex  ### Clear the page before starting every object's log form
    echo "\input{${BUILD_DIR}/${object_underscored}}" >> ${BUILD_DIR}/Objects.tex

    #### Write a LaTeX entry into the Checklist.tex file to include this object in the checklist
    object_count=$(($object_count+1)) # Increment object count before writing into Checklist / ConstType, so serial numbers begin with 1.
    if [ $DEBUG ]; then echo "Writing entry into Checklist file"; fi;
    echo "${object_count} & ${Name_Display} & ${Object_Type} & ${Constellation} & $ ${mag} $ & $ ${maj_axis}' \times ${min_axis}' $ & \pageref{$object_underscored} &  & \\\\ \hline" >> ${BUILD_DIR}/Checklist.tex

    #### Write an entry into ConstType.txt to generate indexes containing objects by constellation and type
    if [ $DEBUG ]; then echo "Writing entry into ConstType.txt file for generation of index by constellation and type"; fi;
    echo "${Constellation}|${Object_Type}|${object_underscored}|${object}|${object_count}|${Name_Display}" >> ${BUILD_DIR}/ConstType.txt

    ## If we are overflowing a page (~ 65 entries) of the checklist, close the table, clearpage, and start afresh on the next page.
    checklist_count=$(($checklist_count+1))
    if [ $DEBUG ]; then echo "Object count: ${object_count}; Checklist count: ${checklist_count}; Total objects: ${TOTAL_OBJECTS}"; fi;
    if [ ${checklist_count} -ge 55 -a ${object_count} -lt ${TOTAL_OBJECTS} ]; then
	if [ $DEBUG ]; then echo "Hit per-page limit for checklist before we're done. Creating a new page."; fi;
	echo "\end{tabular}
}
\clearpage
\resizebox{\textwidth}{!}{
\centering
%\newcolumntype{C}{>{\centering\arraybackslash} m{0.1\textwidth}}
\begin{tabular}{|r||c|c|c|c|c|c||c|c|}
\hline
Sl.No. & Object & Type & Constellation & Mag. & Size & Page & Obs. Date & Second Obs.\\\\
\hline
\hline
" >> ${BUILD_DIR}/Checklist.tex
	checklist_count=0;
    fi;

    #### Write progress text to terminal
    echo "Object-wise Progress: " `echo "100*${object_count}/${TOTAL_OBJECTS}" | bc`"%";
    
done <$OBJECTLIST_FILE;

##### Close up the checklist file
echo "\end{tabular}
}" >> ${BUILD_DIR}/Checklist.tex

##### Generate sorted lists of constellations and types
if [ $DEBUG ]; then echo "Making lists of constellations and types in Constellations.txt and Types.txt."; fi;
cat ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $1 }' | sort | uniq > ${BUILD_DIR}/Constellations.txt
cat ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $2 }' | sort | uniq > ${BUILD_DIR}/Types.txt

##### Generate object list by constellation
while read Constellation; do
    if [ $DEBUG ]; then echo "Writing constellation-wise index for constellation ${Constellation}"; fi;
    echo "\subsection*{${Constellation}}" >> ${BUILD_DIR}/ObjectsByConstellation.tex
    grep "^${Constellation}|" ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $NF " (\\pageref{" $3 "})" "\\\\" }' | sort >> ${BUILD_DIR}/ObjectsByConstellation.tex
done < ${BUILD_DIR}/Constellations.txt;

##### Generate object list by type
while read Type; do
    if [ $DEBUG ]; then echo "Writing object-type-wise index for object type ${Type}"; fi;
    echo "\subsection*{${Type}}" >> ${BUILD_DIR}/ObjectsByType.tex
    grep "^[^|]*|${Type}|" ${BUILD_DIR}/ConstType.txt | awk -F'|' '{ print $NF " (\\pageref{" $3 "})" "\\\\" }' | sort >> ${BUILD_DIR}/ObjectsByType.tex
done < ${BUILD_DIR}/Types.txt;

##### Invoke PDFLaTeX twice to generate the PDFs
if [ $DEBUG ]; then echo "Done generating sources. Invoking pdflatex"; fi;
pdflatex -interaction nonstopmode -output-directory ${BUILD_DIR} ${MAIN_TEX_FILE}
pdflatex -interaction nonstopmode -output-directory ${BUILD_DIR} ${MAIN_TEX_FILE}
cp ${BUILD_DIR}/`echo ${MAIN_TEX_FILE} | sed 's/tex/pdf/'` Output.pdf
if [ $DEBUG ]; then echo "Script finished!"; fi;

