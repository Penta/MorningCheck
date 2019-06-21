#! /bin/bash
#
# Module pour le morning check permettant de monitorer l'espace libre sur
# les disques/partitions via le retour de la commande df.
#
# Par Andy Esnard - v1.1 - 01/03/2019

# Vérification si le script est lancé directement
if [ -z "$MORNING_CHECK" ]; then
	echo "Please do not start this module directly! Use the morning check script instead."
	exit 1
fi

# Path du fichier de la liste des machines
fileList="$(loadConf "fileList" "$MORNING_LISTDIR/machine.txt")"

echo "Checking disks from $fileList..."

# Palier en pourcentage pour l'ulisation des disques.
warningDisk=$(loadConf "warningDisk" "70")
criticalDisk=$(loadConf "criticalDisk" "85")

# Disques à ignorer dans le check des disques.
ignoreDiskString=$(loadConf "ignoreDisk" "")

# Si le fichier de liste n'existe pas
if [ ! -f $fileList ]; then
	echo "ERROR! The list file does not exist."
fi

diskList=()
index=0

# On lit le contenu du fichier et on le met dans un array
while read line; do
	if ! [[ $line = \#* ]]; then
		if ! [ -z "$line" ]; then
			diskList[$index]="$line"
			index=$(($index+1))
		fi
	fi
done < $fileList

# Si le contenu du fichier est vide
if [ ${#diskList[@]} -eq 0 ]; then
	echo "ERROR! The list file is empty."
else
	toHTML "<h2>Disks check:</h2>"

	ignoreDiskString=$(echo "$ignoreDiskString" | tr ',' ' ') # On remplace les virgules par des espaces (plus simple pour la boucle for)
	index=0

	# On convertie la string des disques ignorés en array
	for disk in $ignoreDiskString; do
		ignoreDisk[$index]=$disk
		index=$(($index+1))
	done

	# Pour chaque machine dans le fichier de liste
	for disk in "${diskList[@]}"; do
		# Si on vérifie la machine locale
		if [ "$disk" = "localhost" ]; then
			result=$(df -h | sed 1d)
			toHTML "<h4>$HOSTNAME:</h4>"
		else # On passe par SSH
			result=$(ssh -p $MORNING_SSHPORT -l $MORNING_SSHUSER -q $disk df -h | sed 1d)
			toHTML "<h4>$disk:</h4>"
		fi

		# Si la commande n'a pas renvoyée de retour
		if [ -z "$result" ]; then
			toHTML "<p style='background-color: $MORNING_REDCOLOR;'>An error occured! Please check on the machine.</p>"
		else # Sinon, si on a un retour
			toHTML "<table>"
			toHTML "<tr><b><th>Filesystem</th> <th>Size</th> <th>Used</th> <th>Avail</th> <th>Use%</th> <th>Mounted on</th></b></tr>"
			
			#Pour chaque ligne de résultat de la commande df
			printf %s "$result" | while read -r line; do
				i=0 # Permet de compter la position du mot
				ignoreBool="false"

				# Pour chaque mot dans la ligne
				for value in $line; do
					if [ $i -eq 0 ]; then # Si c'est le premier mot de la ligne
						# On vérifie si le disque ne doit pas être ignoré
						for ignored in "${ignoreDisk[@]}"; do
							if [ "$value" = "$ignored" ]; then
								ignoreBool="true"
							fi
						done

						if [ "$ignoreBool" = "false" ]; then
							toHTML "<tr>"
							toHTML "<td>$value</td>"
						fi
					else # Si ce n'est pas le premier mot de la ligne
						if [ "$ignoreBool" = "false" ]; then # Si ça n'est pas un disque ignoré
							if [ $i -eq 4 ]; then # Si c'est la colonne du pourcentage utilisé
								currentDisk=$(echo "$value" | tr -d %) # On récupère sa valeur sans le pourcentage

								# Et on la compare avec les paliers configurés
								if [ $currentDisk -ge $criticalDisk ]; then
									toHTML "<td bgcolor='$MORNING_REDCOLOR'>$value</td>"
								elif [ $currentDisk -ge $warningDisk ]; then
									toHTML "<td bgcolor='$MORNING_YELLOWCOLOR'>$value</td>"
								else
									toHTML "<td bgcolor='$MORNING_GREENCOLOR'>$value</td>"
								fi
							else
								toHTML "<td>$value</td>"
							fi
						fi
					fi

					i=$(($i + 1)) # On incrémente le compteur de position du mot
				done

				if [ "$ignoreBool" = "false" ]; then
					toHTML "</tr>"
				fi
			done

			toHTML "</table>"
		fi
	done
fi
