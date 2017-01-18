#!/bin/bash

# Usage: metro.sh [ list | ls ]
#        metro.sh [ STATION_PATTERN ]

HOST="89.140.110.107"
PORT="2733"

getValue () {
    regex="<$1>(.*)</$1>"
    if [[ $RESPONSE =~ $regex ]]; then
        echo ${BASH_REMATCH[1]}
    fi
}

printDest () {
    d=$(getValue "$1"); [[ "$d" ]] && printf "%s:#%2d min.\n" "$d" $(getValue "$2")
}

normalize () {
    echo "$@" | sed 'y/áÁéÉíÍóÓúÚñ/aAeEiIoOuUn/'
}

# Request station list
RAW="$(curl --silent http://${HOST}:${PORT}/estaciones.txt | iconv -f iso8859-1 -t utf-8)"

if [[ "$1" == "list" ]] || [[ "$1" == "ls" ]]; then
    echo "$RAW" | cut -d, -f2
    exit 0
fi

# Find station
PATTERN="$(normalize ${@:-principes})" # Default 'Parque de los Príncipes'
STATION=$(normalize "$RAW" | grep -i -- "${PATTERN}" | cut -d, -f1)
if [[ "$STATION" == "" ]]; then (>&2 echo "Nanai") ; exit 1; fi
for s in $STATION; do
    STATION_NAME=$(echo "$RAW" | grep -e "^${s}," | cut -d, -f2)

    # Request time
    RESPONSE="$(curl --silent --header "Content-Type: text/xml;charset=UTF-8" \
         --header "SOAPAction GetEstimacionHoraria" "http://${HOST}:${PORT}/Service_SIV.asmx" \
         --data '<?xml version="1.0" encoding="utf-8"?>
                 <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                                xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                   <soap:Body>
                     <GetEstimacionHoraria xmlns="http://SIV_Server/WebService_SIV">
                       <IdEstacion>'${s}'</IdEstacion>
                     </GetEstimacionHoraria>
                   </soap:Body>
                 </soap:Envelope>')"

    # Print output
    echo -e "\n* Station: ${STATION_NAME}"
    {
        echo " # "
        printDest Destino1_via_1 EstimacionTren1_via_1
        printDest Destino2_via_1 EstimacionTren2_via_1
        echo " # "
        printDest Destino1_via_2 EstimacionTren1_via_2
        printDest Destino2_via_2 EstimacionTren2_via_2
    } | column -t -s#

done
