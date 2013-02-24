### Hacks to replace bad DSS images with good ones
### Run this first, and then run the logbook generating script allowing for DSS reuse
### Also make sure DSS_RESIZE is set correctly, and run in main directory, not under build/
DSS_RESIZE="1024>"


#### MESSIER ####
wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_ir&r=18+18+48&d=-13+47+50&h=35.0&w=35.0&e=J2000&f=gif&c=none&fov=NONE" -O build/M_16_dss.gif
convert build/M_16_dss.gif -negate -resize "${DSS_RESIZE}" build/M_16_dss.png
echo "(I, $35.0' \times 35.0'$)" > build/M_16_dss_metadata.txt
rm build/M_16_dss.gif

wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_ir&r=05+35+17&d=-05+23+25&h=45.0&w=50.0&e=J2000&f=gif&c=none&fov=NONE" -O build/M_42_dss.gif
convert build/M_42_dss.gif -negate -resize "${DSS_RESIZE}" build/M_42_dss.png
echo "(I, $50.0' \times 45.0'$)" > build/M_42_dss_metadata.txt
rm build/M_42_dss.gif

wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_ir&r=05+35+31&d=-05+16+03&h=15.0&w=20.0&e=J2000&f=gif&c=none&fov=NONE" -O build/M_43_dss.gif
convert build/M_43_dss.gif -negate -resize "${DSS_RESIZE}" build/M_43_dss.png
echo "(I, $20.0' \times 15.0'$)" > build/M_43_dss_metadata.txt
rm build/M_43_dss.gif

wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_red&r=12+18+57&d=+47+18+25&h=15.0&w=15.0&e=J2000&f=gif&c=none&fov=NONE" -O build/M_106_dss.gif
convert build/M_106_dss.gif -negate -resize "${DSS_RESIZE}" build/M_106_dss.png
echo "(R, $15.0' \times 15.0'$)" > build/M_106_dss_metadata.txt
rm build/M_106_dss.gif


#### Globular Clusters ####
wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_red&r=17+05+09&d=-22+42+27&h=15.0&w=15.0&e=J2000&f=gif&c=none&fov=NONE" -O build/NGC_6287_dss.gif
convert build/NGC_6287_dss.gif -negate -resize "${DSS_RESIZE}" build/NGC_6287_dss.png
echo "(R, $15.0' \times 15.0'$)" > build/NGC_6287_dss_metadata.txt
rm build/NGC_6287_dss.gif

wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_red&r=18+59+33&d=-36+37+52&h=18.0&w=18.0&e=J2000&f=gif&c=none&fov=NONE" -O build/NGC_6723_dss.gif
convert build/NGC_6723_dss.gif -negate -resize "${DSS_RESIZE}" build/NGC_6723_dss.png
echo "(R, $18.0' \times 18.0'$)" > build/NGC_6723_dss_metadata.txt
rm build/NGC_6723_dss.gif


#### Galaxies ####

# This hack is necessary mostly because KStars has a bug...
wget "http://archive.stsci.edu/cgi-bin/dss_search?v=poss2ukstu_blue&r=00+15+08&d=-39+13+10&h=15&w=32.8&e=J2000&f=gif&c=none&fov=NONE" -O build/NGC_55_dss.gif
convert build/NGC_55_dss.gif -negate -resize "${DSS_RESIZE}" build/NGC_55_dss.png
echo "(B, $32.8' \times 15.0'$)" > build/NGC_55_dss_metadata.txt
rm build/NGC_55_dss.gif
