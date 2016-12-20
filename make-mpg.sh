#!/bin/bash

echo -e "=========================="
echo -e "MPEG Maker (from JPEG tar)"
echo -e "=========================="
echo ""

JPEG_TAR_FILE=${1}
OUTPUT_PATH=${2}

if [ -z "${JPEG_TAR_FILE}" ]
then
  echo "ERROR: full path to the JPEG tar file required."
  exit 1
fi

if [ -z "${FFMPEG_EXEC}" ]
then
  FFMPEG_EXEC=ffmpeg
  echo "FFMPEG execuatable not set. Setting to default: ${FFMPEG_EXEC}"
fi

if [ ! -x "${FFMPEG_EXEC}" ]
then
  echo "ERROR: ${FFMPEG_EXEC} not found or not executable."
  exit 2
fi

TEMP_DIR=tmp
OUTPUT_DIR=~/output
rm -rf ${TEMP_DIR}
mkdir -p ${TEMP_DIR}

SOURCES_FILE=sources.txt
rm -f ${SOURCES_FILE}
touch ${SOURCES_FILE}

if [ -z "${OUTPUT_PATH}" ]
then
  OUTPUT_PATH=${OUTPUT_DIR}/$(basename ${JPEG_TAR_FILE} | sed 's/jpegs\-//;s/\.tar//').mpg
fi

echo -e "JPEG_TAR_FILE:\t${JPEG_TAR_FILE}"
echo -e "OUTPUT_PATH:\t${OUTPUT_PATH}"
echo ""

echo "Expanding JPEG tar file: ${JPEG_TAR_FILE} ..."
tar -xf ${JPEG_TAR_FILE} -C ${TEMP_DIR}

STARTED=0
echo "Creating sources file ${SOURCES_FILE} ..."
find ${TEMP_DIR} -name '*.jpg' | sort > ${TEMP_DIR}/${SOURCES_FILE}

while read JPG_FILE; do
  echo "file '${JPG_FILE}'" >> ${SOURCES_FILE}
done < ${TEMP_DIR}/${SOURCES_FILE}

rm -f ${OUTPUT_PATH}
${FFMPEG_EXEC} -f concat -i ${SOURCES_FILE} -q:v 5 ${OUTPUT_PATH}
FFMPEG_RET=$?

echo -e "=========================="
echo ""
if [[ $FFMPEG_RET -gt 0 ]]; then
  echo "!!!!!!!!!"
  echo "ERROR: ffmpeg returned a non-zero status code. Please look for error messages above."
  echo "!!!!!!!!!"
  echo ""
  exit 3
fi

echo ""
echo -e "SUCCESS! Created output file: ${OUTPUT_PATH}"
echo ""
