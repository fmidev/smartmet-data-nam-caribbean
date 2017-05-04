#!/bin/sh
#
# Finnish Meteorological Institute / Mikko Rauhala (2014-2017)
#
# SmartMet Data Ingestion Module for NAM Caribbean Model
#

if [ -s /smartmet/cnf/data/nam-caribbean.cnf ]; then
    . /smartmet/cnf/data/nam-caribbean.cnf
fi

if [ -s nam-caribbean.cnf ]; then
    . nam-caribbean.cnf
fi

# Setup defaults for the configuration

if [ -z "$AREA" ]; then
    AREA=caribbean
fi

if [ -z "$INTERVALS" ]; then
    INTERVALS=("0 3 84")
fi

while getopts  "a:b:di:l:r:t:" flag
do
  case "$flag" in
        a) AREA=$OPTARG;;
        d) DRYRUN=1;;
        i) INTERVALS=("$OPTARG");;
        l) LEFT=$OPTARG;;
        r) RIGHT=$OPTARG;;
        t) TOP=$OPTARG;;
        b) BOTTOM=$OPTARG;;
  esac
done

STEP=6
# Model Reference Time
RT=`date -u +%s -d '-3 hours'`
RT="$(( $RT / ($STEP * 3600) * ($STEP * 3600) ))"
RT_HOUR=`date -u -d@$RT +%H`
RT_DATE=`date -u -d@$RT +%Y%m%d`
RT_DATE_HH=`date -u -d@$RT +%Y%m%d%H`
RT_DATE_HHMM=`date -u -d@$RT +%Y%m%d%H%M`
RT_ISO=`date -u -d@$RT +%Y-%m-%dT%H:%M:%SZ`

if [ -d /smartmet ]; then
    OUT=/smartmet/data/nam/$AREA
    CNF=/smartmet/run/data/nam/cnf
    EDITOR=/smartmet/editor/in
    TMP=/smartmet/tmp/data/nam_${AREA}_${RT_DATE_HHMM}
    LOGFILE=/smartmet/logs/data/nam_${AREA}_${RT_HOUR}.log
else
    OUT=$HOME/data/nam/$AREA
    CNF=/smartmet/run/data/nam/cnf
    EDITOR=/smartmet/editor/in
    TMP=/tmp/nam_${AREA}_${RT_DATE_HHMM}
    LOGFILE=/smartmet/logs/data/nam_caribbean_${RT_HOUR}.log
fi

CNF=/smartmet/run/data/nam/cnf

OUTNAME=${RT_DATE_HHMM}_nam_$AREA

# Log everything
#if [ ! -t 0 ]; then
#    exec &> $LOGFILE
#fi

echo "Model Reference Time: $RT_ISO"
echo "Area: $AREA left:$LEFT right:$RIGHT top:$TOP bottom:$BOTTOM"
echo -n "Interval(s): "
for l in "${INTERVALS[@]}"
do
    echo -n "$l "
done
echo ""
echo "Temporary directory: $TMP"
echo "Output directory: $OUT"
echo "Output surface level file: ${OUTNAME}_surface.sqd"
echo "Output pressure level file: ${OUTNAME}_pressure.sqd"

if [ -z "$DRYRUN" ]; then
    mkdir -p $TMP/grb
    mkdir -p $OUT/{surface,pressure}/querydata
fi

function runBacground()
{
    downloadStep $1 &
    ((dnum=dnum+1))
    if [ $(($dnum % 6)) == 0 ]; then
	wait
    fi
}

function testFile()
{
    if [ -s $1 ]; then
    # check return value, break if successful (0)
        gdalinfo $1 &>/dev/null
        if [ $? = 0 ]; then
            return 0
    else
            rm -f $1
            return 1
        fi
    else
        return 1
    fi
}


function downloadStep()
{
    STEPSTARTTIME=$(date +%s)
    step=$(printf '%02d' $1)
    FILE="nam.t${RT_HOUR}z.afwaca${step}.tm00.grib2"

    if [ -n "$DRYRUN" ]; then
	echo $FILE
	return
    fi

    if $(testFile ${TMP}/grb/${FILE}); then
        echo "Cached file: $FILE size: $(stat --printf="%s" ${TMP}/grb/${FILE}) messages: $(wgrib2 ${TMP}/grb/${FILE}|wc -l):"
        break;
    else
	while [ 1 ]; do
	    ((count=count+1))
	    echo "Downloading (try: $count) $TMP/grb/${FILE}"

	    STARTTIME=$(date +%s)
	    curl -s -S -o $TMP/grb/${FILE} "http://nomads.ncep.noaa.gov/cgi-bin/filter_nam_crb.pl?file=${FILE}&lev_1000_mb=on&lev_100_mb=on&lev_10_m_above_ground=on&lev_125_mb=on&lev_150_mb=on&lev_175_mb=on&lev_200_mb=on&lev_225_mb=on&lev_275_mb=on&lev_2_m_above_ground=on&lev_300_mb=on&lev_325_mb=on&lev_350_mb=on&lev_375_mb=on&lev_400_mb=on&lev_425_mb=on&lev_450_mb=on&lev_475_mb=on&lev_500_mb=on&lev_525_mb=on&lev_550_mb=on&lev_575_mb=on&lev_600_mb=on&lev_625_mb=on&lev_650_mb=on&lev_675_mb=on&lev_700_mb=on&lev_725_mb=on&lev_750_mb=on&lev_775_mb=on&lev_800_mb=on&lev_825_mb=on&lev_850_mb=on&lev_875_mb=on&lev_900_mb=on&lev_925_mb=on&lev_950_mb=on&lev_975_mb=on&lev_entire_atmosphere_%5C%28considered_as_a_single_layer%5C%29=on&lev_mean_sea_level=on&lev_surface=on&var_APCP=on&var_CAPE=on&var_CIN=on&var_HGT=on&var_ICEC=on&var_LAND=on&var_PRES=on&var_PRMSL=on&var_PWAT=on&var_RH=on&var_SNOD=on&var_SOILL=on&var_SOILW=on&var_SPFH=on&var_TCDC=on&var_TMP=on&var_UGRD=on&var_VGRD=on&var_VIS=on&var_VVEL=on&leftlon=0&rightlon=360&toplat=90&bottomlat=-90&dir=%2Fnam.${RT_DATE}"
	    ENDTIME=$(date +%s)
            if $(testFile ${TMP}/grb/${FILE}); then
                echo "Downloaded file: $FILE size: $(stat --printf="%s" ${TMP}/grb/${FILE}) messages: $(wgrib2 ${TMP}/grb/${FILE}|wc -l) time: $(($ENDTIME - $STARTTIME))s wait: $((($ENDTIME - $STEPSTARTTIME) - ($ENDTIME - $STEPSTARTTIME)))s"
                break;
            fi

	    if [ $count = 60 ]; then break; fi; 
	    sleep 60
	done # while 1

    fi
}

# Download intervals
for l in "${INTERVALS[@]}"
do
    echo "Downloading interval $l"
    for i in $(seq $l)
    do
#        if [ -n "$DRYRUN" ]; then
#            echo -n "$i "
#    else
            runBacground $i
#        fi
    done
    if [ -n "$DRYRUN" ]; then
    echo ""
    fi
done

if [ -n "$DRYRUN" ]; then
    exit
fi

# Wait for the downloads to finish
wait

echo ""
echo "Download size $(du -hs $TMP/grb/|cut -f1) and $(ls -1 $TMP/grb/|wc -l) files."

echo "Converting grib files to qd files..."
gribtoqd -v -n -d -t -p "56,NAM Surface,NAM Pressure" -o $TMP/$OUTNAME.sqd $TMP/grb/
if [ -s $TMP/$OUTNAME.sqd_levelType_1 ]; then
mv -f $TMP/$OUTNAME.sqd_levelType_1 $TMP/${OUTNAME}_surface.sqd
fi
if [ -s $TMP/$OUTNAME.sqd_levelType_100 ]; then
mv -f $TMP/$OUTNAME.sqd_levelType_100 $TMP/${OUTNAME}_pressure.sqd
fi

#
# Post process some parameters 
#
echo -n "Calculating parameters: pressure..."
cp -f  $TMP/${OUTNAME}_pressure.sqd $TMP/${OUTNAME}_pressure.sqd.tmp
echo -n "surface..."
qdscript -a 354 $CNF/nam-surface.st < $TMP/${OUTNAME}_surface.sqd > $TMP/${OUTNAME}_surface.sqd.tmp
echo "done"

#
# Create querydata totalWind and WeatherAndCloudiness objects
#
echo -n "Creating Wind and Weather objects: pressure..."
qdversionchange -w 0 7 < $TMP/${OUTNAME}_pressure.sqd.tmp > $TMP/${OUTNAME}_pressure.sqd
echo -n "surface..."
qdversionchange -a 7 < $TMP/${OUTNAME}_surface.sqd.tmp > $TMP/${OUTNAME}_surface.sqd
echo "done"

#
# Copy files to SmartMet Workstation and SmartMet Production directories
# Bzipping the output file is disabled until all countries get new SmartMet version
# Pressure level
if [ -s $TMP/${OUTNAME}_pressure.sqd ]; then
    echo -n "Compressing pressure data..."
    bzip2 -k $TMP/${OUTNAME}_pressure.sqd
    echo "done"
    echo -n "Copying file to SmartMet Workstation..."
    mv -f $TMP/${OUTNAME}_pressure.sqd $OUT/pressure/querydata/${OUTNAME}_pressure.sqd
    mv -f $TMP/${OUTNAME}_pressure.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created file: ${OUTNAME}_pressure.sqd"
fi

# Surface
if [ -s $TMP/${OUTNAME}_surface.sqd ]; then
    echo -n "Compressing surface data..."
    bzip2 -k $TMP/${OUTNAME}_surface.sqd
    echo "done"
    echo -n "Copying file to SmartMet Production..."
    mv -f $TMP/${OUTNAME}_surface.sqd $OUT/surface/querydata/${OUTNAME}_surface.sqd
    mv -f $TMP/${OUTNAME}_surface.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created file: ${OUTNAME}_surface.sqd"
fi

rm -f $TMP/*_nam_*
rm -f $TMP/grb/nam*
rmdir $TMP/grb
rmdir $TMP

