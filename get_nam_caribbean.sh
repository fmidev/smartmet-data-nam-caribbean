#!/bin/sh
#
# Finnish Meteorological Institute / Mikko Rauhala (2014-2019)
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
    BASE=/smartmet
else
    BASE=$HOME/smartmet
fi

OUT=$BASE/data/nam/$AREA
CNF=$BASE/run/data/nam/cnf
EDITOR=$BASE/editor/in
TMP=$BASE/tmp/data/nam_${AREA}_${RT_DATE_HHMM}
LOGFILE=$BASE/logs/data/nam_${AREA}_${RT_HOUR}.log

OUTNAME=${RT_DATE_HHMM}_nam_$AREA

# Use log file if not run interactively
if [ $TERM = "dumb" ]; then
    exec &> $LOGFILE
fi

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
    mkdir -p $EDITOR
fi

function log {
    echo "$(date -u +%H:%M:%S) $1"
}

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
        grib_count $1 &>/dev/null
	if [ $? = 0 ] && [ $(grib_count $1) -gt 0 ]; then
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
        log "Cached file: $FILE size: $(stat --printf="%s" ${TMP}/grb/${FILE}) messages: $(grib_count ${TMP}/grb/${FILE})"
        break;
    else
	while [ 1 ]; do
	    ((count=count+1))
	    log "Downloading (try: $count) $TMP/grb/${FILE}"

	    STARTTIME=$(date +%s)
	    curl -s -S -o $TMP/grb/${FILE} "https://nomads.ncep.noaa.gov/cgi-bin/filter_nam_crb.pl?file=${FILE}&lev_1000_mb=on&lev_100_mb=on&lev_10_m_above_ground=on&lev_125_mb=on&lev_150_mb=on&lev_175_mb=on&lev_200_mb=on&lev_225_mb=on&lev_275_mb=on&lev_2_m_above_ground=on&lev_300_mb=on&lev_325_mb=on&lev_350_mb=on&lev_375_mb=on&lev_400_mb=on&lev_425_mb=on&lev_450_mb=on&lev_475_mb=on&lev_500_mb=on&lev_525_mb=on&lev_550_mb=on&lev_575_mb=on&lev_600_mb=on&lev_625_mb=on&lev_650_mb=on&lev_675_mb=on&lev_700_mb=on&lev_725_mb=on&lev_750_mb=on&lev_775_mb=on&lev_800_mb=on&lev_825_mb=on&lev_850_mb=on&lev_875_mb=on&lev_900_mb=on&lev_925_mb=on&lev_950_mb=on&lev_975_mb=on&lev_entire_atmosphere_%5C%28considered_as_a_single_layer%5C%29=on&lev_mean_sea_level=on&lev_surface=on&var_APCP=on&var_CAPE=on&var_CIN=on&var_HGT=on&var_ICEC=on&var_LAND=on&var_PRES=on&var_PRMSL=on&var_PWAT=on&var_RH=on&var_SNOD=on&var_SOILL=on&var_SOILW=on&var_SPFH=on&var_TCDC=on&var_TMP=on&var_UGRD=on&var_VGRD=on&var_VIS=on&var_VVEL=on&var_DPT=on&leftlon=0&rightlon=360&toplat=90&bottomlat=-90&dir=%2Fnam.${RT_DATE}"
	    ENDTIME=$(date +%s)
            if $(testFile ${TMP}/grb/${FILE}); then
                log "Downloaded file: $FILE size: $(stat --printf="%s" ${TMP}/grb/${FILE}) messages: $(grib_count ${TMP}/grb/${FILE}) time: $(($ENDTIME - $STARTTIME))s wait: $((($ENDTIME - $STEPSTARTTIME) - ($ENDTIME - $STEPSTARTTIME)))s"
                if [ -n "$GRIB_COPY_DEST" ]; then
                    rsync -ra  ${TMP}/grb/${FILE} $GRIB_COPY_DEST/$RT_DATE_HH/
                fi
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
        runBacground $i
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

if [ -n "$GRIB_COPY_DEST" ]; then
    ls -1 $TMP/grb/ > $TMP/${RT_DATE_HH}.txt
    rsync -a $TMP/${RT_DATE_HH}.txt $GRIB_COPY_DEST/
fi

log "Download size $(du -hs $TMP/grb/|cut -f1) and $(ls -1 $TMP/grb/|wc -l) files."

log "Converting surface grib files to qd files..."
gribtoqd -d -t -L 1 -p "56,NAM Surface" -c $CNF/nam-gribtoqd.cnf -o $TMP/${OUTNAME}_surface.sqd $TMP/grb/
gribtoqd -d -t -L 100 -p "56,NAM Surface" -c $CNF/nam-gribtoqd.cnf -o $TMP/${OUTNAME}_pressure.sqd $TMP/grb/

#
# Post process some parameters 
#
log "Post processing ${OUTNAME}_pressure.sqd"
cp -f  $TMP/${OUTNAME}_pressure.sqd $TMP/${OUTNAME}_pressure.sqd.tmp
log "Post processing ${OUTNAME}_surface.sqd"
qdscript -a 354 $CNF/nam-caribbean-surface.st < $TMP/${OUTNAME}_surface.sqd > $TMP/${OUTNAME}_surface.sqd.tmp

#
# Create querydata totalWind and WeatherAndCloudiness objects
#
log "Creating Wind and Weather objects: ${OUTNAME}_pressure.sqd"
qdversionchange -w 0 7 < $TMP/${OUTNAME}_pressure.sqd.tmp > $TMP/${OUTNAME}_pressure.sqd
log "Creating Wind and Weather objects: ${OUTNAME}_surface.sqd"
qdversionchange -a 7 < $TMP/${OUTNAME}_surface.sqd.tmp > $TMP/${OUTNAME}_surface.sqd

#
# Copy files to SmartMet Workstation and SmartMet Production directories
# Bzipping the output file is disabled until all countries get new SmartMet version
# Pressure level
if [ -s $TMP/${OUTNAME}_pressure.sqd ]; then
    log "Testing ${OUTNAME}_pressure.sqd"
    if qdstat $TMP/${OUTNAME}_pressure.sqd; then
	log  "Compressing ${OUTNAME}_pressure.sqd"
	lbzip2 -k $TMP/${OUTNAME}_pressure.sqd
	log "Moving ${OUTNAME}_pressure.sqd to $OUT/pressure/querydata/"
	mv -f $TMP/${OUTNAME}_pressure.sqd $OUT/pressure/querydata/
	log "Moving ${OUTNAME}_pressure.sqd.bz2 to $EDITOR/"
	mv -f $TMP/${OUTNAME}_pressure.sqd.bz2 $EDITOR/
    else
        log "File $TMP/${OUTNAME}_pressure.sqd is not valid qd file."
    fi
fi

# Surface
if [ -s $TMP/${OUTNAME}_surface.sqd ]; then
    log "Testing ${OUTNAME}_surface.sqd"
    if qdstat $TMP/${OUTNAME}_surface.sqd; then
        log "Compressing ${OUTNAME}_surface.sqd"
	lbzip2 -k $TMP/${OUTNAME}_surface.sqd
	log "Moving ${OUTNAME}_surface.sqd to $OUT/surface/querydata/"
	mv -f $TMP/${OUTNAME}_surface.sqd $OUT/surface/querydata/
	log "Moving ${OUTNAME}_surface.sqd.bz2 to $EDITOR"
	mv -f $TMP/${OUTNAME}_surface.sqd.bz2 $EDITOR/
    else
        log "File $TMP/${OUTNAME}_surface.sqd is not valid qd file."
    fi
fi

rm -f $TMP/*_nam_*
rm -f $TMP/grb/nam*
rmdir $TMP/grb
rmdir $TMP

