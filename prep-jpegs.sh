#!/bin/bash

EVENT_LIST_FILE=${1}
OUTPUT_FILENAME=${2}

if [ -z ${EVENT_LIST_FILE} ]; then
  echo "ERROR: Path to event list file is required."
  echo -e "\tEach line: <monitor-id> <begin-path> <end-path> <frames-to-skip>"
  exit 1
fi

if [ -z "${OUTPUT_FILENAME}" ]
then
  OUTPUT_FILENAME=$(basename ${EVENT_LIST_FILE} | sed 's/\.txt//')
  echo "INFO: No output jpeg sources filename provided. Using default filename: ${OUTPUT_FILENAME}.tar"
fi

# For ZM 1.30.x
#zm_events_path="/var/cache/zoneminder/events"
# For ZM 1.26.x
zm_events_path=/var/www/zm/events

TEMP_DIR=~/temp/zm-tmp
TAR_DIR=${TEMP_DIR}/tar
OUTPUT_DIR=~/output
rm -rf ${TEMP_DIR}
mkdir -p ${TAR_DIR}
mkdir -p ${OUTPUT_DIR}

SOURCES_FILE=sources.txt
rm -f ${SOURCES_FILE}
touch ${SOURCES_FILE}

build_transform () {
  local path_parts
  local break_string
  IFS='/' read -ra path_parts <<< $1
  break_string=$2
  
  local xform=''
  local path_part
  local sep
  for (( i = 0; i < ${#path_parts[@]}; i++ )); do
    path_part=${path_parts[$i]}
    if [[ -z $path_part ]]; then continue; fi
    if [[ -z $xform ]]; then sep=''; else sep=';'; fi
    xform=${xform}${sep}"s,/,,;s,${path_part},,"
    if [[ ${path_part} == ${break_string} ]]; then
      break;
    fi
  done
  xform=${xform}';s,/,-,g;s,-capture,,'
  echo ${xform}
}

processPaths () {
  local temp_source_dir=${TEMP_DIR}/${CNT}
  mkdir -p ${temp_source_dir}
  local temp_source=${temp_source_dir}/${SOURCES_FILE}
  local monitor_id=$1
  local begin_path=$2
  local end_path=$3
  local frames_skip=$4
  echo -e "=================> Processing monitor: ${monitor_id} - ${begin_path} to ${end_path} - frames_skip: ${frames_skip} ..."
  
  local begin_parts
  local end_parts
  IFS='/' read -ra begin_parts <<< "${begin_path}"
  IFS='/' read -ra end_parts <<< "${end_path}"
  
  IFS='/' read -ra begin_parts <<< $begin_path
  IFS='/' read -ra end_parts <<< $end_path
  local DIFF_IDX
  # First figure out the DIFF_IDX
  for (( i=0; i<5; i++ )); do
    if [ ${end_parts[$i]} -gt ${begin_parts[$i]} ]; then
      # We found the idx where the end_parts is higher than begin_parts
      DIFF_IDX=$i
      break
    fi
  done
  # if DIFF_IDX hasn't been assigned ...
  if [ ! -n "${DIFF_IDX}" ]; then
    #echo "Begin & end paths are the same. Nothing to do!"
    #return 1
    DIFF_IDX=4
  fi
  
  # An array of path idx max values
  # position 0=year, 1=month, 2=day, 3=hour, 4=minute
  local idx_maxes=(-1 13 32 24 60)

  # Array of path part prefixes to be used in the JPEG gathering loops
  local begin_parts_prefixes=("" \
    "${begin_parts[0]}" \
    "${begin_parts[0]}/${begin_parts[1]}" \
    "${begin_parts[0]}/${begin_parts[1]}/${begin_parts[2]}" \
    "${begin_parts[0]}/${begin_parts[1]}/${begin_parts[2]}/${begin_parts[3]}" \
  )
  local end_parts_prefixes=("" \
    "${end_parts[0]}" \
    "${end_parts[0]}/${end_parts[1]}" \
    "${end_parts[0]}/${end_parts[1]}/${end_parts[2]}" \
    "${end_parts[0]}/${end_parts[1]}/${end_parts[2]}/${end_parts[3]}" \
  )

  local events_path
  local path_value
  local path_value_begin
  local path_value_end
  # Begin index walk-back loop up to DIFF_IDX
  for (( i = 4; i >= ${DIFF_IDX}; i-- )); do
    if [ $i -eq ${DIFF_IDX} ]; then
      path_value_end=$((10#${end_parts[$i]}))
    else
      path_value_end=$((10#${idx_maxes[$i]}))
    fi
    echo -e "begin_parts[$i]=${begin_parts[$i]}, end_parts[$i]=${end_parts[$i]}, path_value_end=${path_value_end}"

    if [ $i -eq 4 ]; then
      path_value_begin=$((10#${begin_parts[$i]}))
    else
      path_value_begin=$((10#${begin_parts[$i]} + 1))
    fi

    # inner loop to iterate over the parts idx=$i
    for (( p = ${path_value_begin}; p < ${path_value_end}; p++ )); do
      path_value=`printf %02d $p`
      events_path=${zm_events_path}/${monitor_id}/${begin_parts_prefixes[$i]}/${path_value}
      if [ ! -d ${events_path} ]; then
        #echo -e "\tNo path: ${events_path} Skipping ..."
        continue
      fi
      echo -e "---> Processing ${events_path} ..."
      find ${events_path} -name '*capture.jpg' | sort >> ${temp_source}
    done
  done

  local forward_start_idx=''
  if [ ${DIFF_IDX} -lt 4 ]; then
    forward_start_idx=$((DIFF_IDX + 1))
  else
    forward_start_idx=${DIFF_IDX}
  fi

  echo -e "===> FORWARD LOOP ... forward_start_idx=${forward_start_idx}, end_value=${end_parts[$forward_start_idx]}"
  local path_value
  for (( i = $forward_start_idx; i <= 4; i++ )); do

    if [ $DIFF_IDX -lt 4 ]; then
      path_value_begin=0;
    else
      path_value_begin=$((10#${end_parts[$i]}));
    fi

    if [ $i -lt 4 ]; then
      path_value_end=$((10#${end_parts[$i]}))
    else
      path_value_end=$((10#${end_parts[$i]} + 1))
    fi

    echo -e "path_value_begin=${path_value_begin}, path_value_end=${path_value_end}"

    # inner loop to iterate over the parts idx=$i
    for (( p = ${path_value_begin}; p < ${path_value_end}; p++ )); do
      path_value=`printf %02d $p`
      events_path=${zm_events_path}/${monitor_id}/${end_parts_prefixes[$i]}/${path_value}
      if [ ! -d ${events_path} ]; then
        #echo -e "\tNo path: ${events_path} Skipping ..."
        continue
      fi
      echo -e "---> Processing ${events_path} ..."
      find ${events_path} -name '*capture.jpg' | sort >> ${temp_source}
    done
  done
  
  local SKIP_CNT
  local SKIP_MSG
  if [ $frames_skip -gt 0 ]; then
    SKIP_CNT=$((frames_skip - 1))
    SKIP_MSG="skipping ${frames_skip} frames"
  else
    SKIP_CNT=0
    SKIP_MSG="no frame skipping"
  fi
  
  local STARTED=0
  local JPG_FILE
  local FLAT_JPG_FILENAME
  echo "Adding to sources file ${SOURCES_FILE} ... (${SKIP_MSG})"
  while read JPG_FILE; do
    if [ $SKIP_CNT -gt 0 ] && [ $STARTED -eq 1 ]; then
      ((SKIP_CNT--))
      continue
    fi

    FLAT_JPG_FILENAME=${JPG_FILE#$zm_events_path/}
    FLAT_JPG_FILENAME="$(echo ${FLAT_JPG_FILENAME} | sed 's/\//\-/g; s/\-capture//')"

    echo "${JPG_FILE}" >> ${SOURCES_FILE}
    SKIP_CNT=$((frames_skip - 1))
    STARTED=1
  done < ${temp_source}
}

CNT=0

while IFS='' read -r line || [[ -n "$line" ]]; do
  ((CNT++))
  echo ""
  tokens=( $line )
  #tokens[0] = monitor_id
  #tokens[1] = begin_path
  #tokens[2] = end_path
  #tokens[3] = frames_skip
  processPaths ${tokens[0]} ${tokens[1]} ${tokens[2]} ${tokens[3]}
done < "${EVENT_LIST_FILE}"

OUTPUT_FILE=${OUTPUT_DIR}/${OUTPUT_FILENAME}.tar
echo -e "CNT: ${CNT}"
echo -e ""

echo "Creating output file ${OUTPUT_FILE} ..."
rm -f ${OUTPUT_FILE}
xform=$(build_transform ${zm_events_path})
tar -cf ${OUTPUT_FILE} --transform=${xform} -T ${SOURCES_FILE}
