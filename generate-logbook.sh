dest_dir='/tmp'
list=''
for messier_number in `seq 1 110`; do
    object_underscored=`echo "M_${messier_number}"`
    object=`echo $object_underscored | sed 's/_/ /g'`
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

    # Export all three sky images
    qdbus org.kde.kstars /KStars org.kde.kstars.lookTowards "$object"
    qdbus org.kde.kstars /KStars org.kde.kstars.setApproxFOV $FOV
    qdbus org.kde.kstars /KStars org.kde.kstars.exportImage ${dest_dir}/${object_underscored}_skychart.svg
    
    skychart_PDF=${dest_dir}/${object_underscored}_skychart.pdf
    inkscape -T -A $skychart_PDF ${dest_dir}/${object_underscored}_skychart.svg

    # Get DSS image
    DSS=${dest_dir}/${object_underscored}_dss.png
    DSS_URL=`qdbus org.kde.kstars /KStars org.kde.kstars.getDSSURL "$object"`
    DSS_size_string=`echo $DSS_URL | sed "s/^.*&h=\([0-9\.]*\)&w=\([0-9\.]*\)&.*$/$\2' \\\\\times \1'$/"`
    wget $DSS_URL -O ${dest_dir}/${object_underscored}_dss.gif
    convert -negate ${dest_dir}/${object_underscored}_dss.gif $DSS

    # Set up the LaTeX
    texfile=${dest_dir}/${object_underscored}.tex
    echo "" > $texfile
    echo "
\documentclass{article}
\usepackage{graphicx}
\usepackage{textcomp}
\usepackage{gensymb}
\usepackage{caption}
\usepackage{subcaption}
\usepackage{float}
\setlength{\oddsidemargin}{-0.5in} 
\setlength{\evensidemargin}{0in}
\setlength{\marginparwidth}{0in}
\setlength{\marginparsep}{0in}
\pagestyle{empty}
\usepackage[top=0.15in, bottom=0.2in, left=0.5in, right=0in]{geometry}

\begin{document}
\title{\Huge ${Name_Display}}
\author{\Large ${Object_Type} in ${Constellation}}
\date{}
\maketitle

\thispagestyle{empty}

%\subsection*{Data}
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
Magnitude & $mag & Other Designation & ${Alt_Name} \\\\
\hline
\end{tabular}
\end{center}

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
\includegraphics[width=0.8\textwidth]{Log-form-only.pdf}
\end{figure}

\end{document}

" >> $texfile

cd $dest_dir
pdflatex -interaction nonstopmode $texfile

list="$list ${object_underscored}.pdf"

done;

pdftk $list cat output Finder-Charts.pdf

