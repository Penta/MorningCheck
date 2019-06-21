#! /bin/bash
#
# Module pour le morning check permettant de surveiller les uptimes
# sur les machines.
#
# Par Andy Esnard - SOGETI - 01/03/2019

# Vérification si le script est lancé directement
if [ -z "$MORNING_CHECK" ]; then
	echo "Please do not start this module directly! Use the morning check script instead."
	exit 1
fi

# Nombre de jour d'uptime minimum pour la couleur verte.
warningUptime=$(loadConf "warningUptime" "1")

# Path du fichier de la liste des machines
fileList="$(loadConf "fileList" "$MORNING_LISTDIR/machine.txt")"

echo "Checking uptimes from $fileList..."

# Si le fichier de liste n'existe pas
if [ ! -f $fileList ]; then
	echo "ERROR! The list file does not exist."
fi

machineList=()
index=0

# On lit le contenu du fichier pour le mettre dans l'array machineList
while read line; do
	if ! [[ $line = \#* ]]; then # On ne prend pas en compte les lignes de commentaire
		if ! [ -z "$line" ]; then # Ni les lignes vides
			machineList[$index]="$line"
			index=$(($index+1))
		fi
	fi
done < $fileList

# Si le contenu du fichier est vide
if [ ${#machineList[@]} -eq 0 ]; then
	echo "ERROR! The list file is empty."
else
	toHTML "<h2>Uptimes check:</h2>"

	toHTML "<table>"
	toHTML "<tr><b><th>Machine</th><th>Uptime</th></b></tr>"

	# Pour chaque machine
	for value in "${machineList[@]}"; do
		toHTML "<tr>"

		# Si on check la machine actuelle, on ne passe pas par SSH
		if [ "$value" = "localhost" ]; then
			result=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes."}')
			toHTML "<td>$HOSTNAME</td>"
		else
			result=$(ssh -p $MORNING_SSHPORT -l $MORNING_SSHUSER -q $value uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes."}')
			toHTML "<td>$value</td>"
		fi

		# Si le résultat est vide
		if [ -z "$result" ]; then
			toHTML "<td bgcolor='$MORNING_REDCOLOR'>An error occured! Please check on the machine.</td>"
		else
			# On ne récupère seulement que le nombre de jour d'uptime
			uptime=$(echo $result | awk -F'( |,|:)+' '{print $1}')

			# Selon le pallier du nombre de jour donné en début de script, on choisit la couleur à afficher
			if [ "$uptime" -le "$(($warningUptime-1))" ]; then 
				toHTML "<td bgcolor='$MORNING_YELLOWCOLOR'>$result</td>"
			else
				toHTML "<td bgcolor='$MORNING_GREENCOLOR'>$result</td>"
			fi
		fi

		toHTML "</tr>"
	done

	toHTML "</table>"
fi
