#! /bin/bash
#
# Module pour le morning check permettant de monitorer l'espace libre sur
# la mémoire RAM via le retour de la commande free.
#
# Par Andy Esnard - v1.1 - 07/03/2019

# Vérification si le script est lancé directement
if [ -z "$MORNING_CHECK" ]; then
	echo "Please do not start this module directly! Use the morning check script instead."
	exit 1
fi

# Path du fichier de la liste des machines
fileList="$(loadConf "fileList" "$MORNING_LISTDIR/machine.txt")"
countCachedMem="$(loadConf "countCachedMem" "false")"

echo "Checking memories from $fileList..."

# Palier en pourcentage pour l'ulisation de la mémoire.
warningMem=$(loadConf "warningMem" "85")
criticalMem=$(loadConf "criticalMem" "95")

# Si le fichier de liste n'existe pas
if [ ! -f $fileList ]; then
	echo "ERROR! The list file does not exist."
fi

machineList=()
index=0

# On lit le contenu du fichier et on le met dans un array
while read line; do
	if ! [[ $line = \#* ]]; then
		if ! [ -z "$line" ]; then
			machineList[$index]="$line"
			index=$(($index+1))
		fi
	fi
done < $fileList

# Si le contenu du fichier est vide
if [ ${#machineList[@]} -eq 0 ]; then
	echo "ERROR! The list file is empty."
else
	toHTML "<h2>Memory check:</h2>"
	
	toHTML "<table>"
	toHTML "<tr><b><th>Machine</th> <th>Total</th> <th>Used</th> <th>Free</th> <th>Cache</th> <th>Available</th> <th>Use%</th></b></tr>"

	index=0
	
	# Pour chaque machine dans le fichier de liste
	for machine in "${machineList[@]}"; do
		freeMem=0
		totalMem=0
		
		toHTML "<tr>"

		# Si on vérifie la machine locale
		if [ "$machine" = "localhost" ]; then
			result=$(free -k | grep "Mem")
			toHTML "<td>$HOSTNAME</td>"
		else # On passe par SSH
			result=$(ssh -p $MORNING_SSHPORT -l $MORNING_SSHUSER -q $machine free -k | grep "Mem")
			toHTML "<td>$machine</td>"
		fi

		# Si la commande n'a pas renvoyée de retour
		if [ -z "$result" ]; then
			toHTML "<td style='background-color: $MORNING_REDCOLOR;' colspan="6">An error occured! Please check on the machine.</td>"
		else # Sinon, si on a un retour
			i=0 # Permet de compter la position du mot

			# Pour chaque mot dans la ligne
			for value in $result; do
				valueFiltered=$(echo "$value" | awk '{print (($1/1024))}' | cut -d. -f1)

				# On fait un affichage des valeurs lisible avec la bonne unité
				if [ $valueFiltered -lt '1024' ]; then
					valueFiltered=$(echo "$valueFiltered MB") 					
				else
					valueFiltered=$(echo "$valueFiltered" | awk '{print (($1/1024))}' | cut -c1-4)
					valueFiltered=$(echo "$valueFiltered GB")
				fi

				if [ $i -eq 0 ]; then # Si c'est le premier mot de la ligne
					echo "useless line" > /dev/null
				elif [ $i -eq 1 ]; then # Si c'est la mémoire totale
					totalMem=$(echo $value)
					toHTML "<td>$valueFiltered</td>"
				elif [ $i -eq 3 ]; then # Si c'est la mémoire libre
					freeMem=$(echo $value)
					toHTML "<td>$valueFiltered</td>"
				elif [ $i -eq 4 ]; then # On n'affiche pas la mémoire partagée
					echo "useless line" > /dev/null
				elif [ $i -eq 6 ]; then # Mémoire dispo
					availMem=$(echo $value)
					toHTML "<td>$valueFiltered</td>"
				else # Si ce n'est pas le premier mot de la ligne
					toHTML "<td>$valueFiltered</td>"
				fi

				i=$(($i + 1)) # On incrémente le compteur de position du mot
			done
			
			if [ $countCachedMem = "true" ]; then
				requestedValueMem=$(echo $freeMem)
			else
				requestedValueMem=$(echo $availMem)
			fi

			percentMem=$(echo "$requestedValueMem $totalMem" | awk '{print (100 - ($1/$2 * 100))}' | cut -c1-4) # On récupère sa valeur en pourcentage
			percentMemFiltered=$(echo "$percentMem" | cut -d. -f1)

			# Et on la compare avec les paliers configurés
			if [ $percentMemFiltered -ge $criticalMem ]; then
				toHTML "<td bgcolor='$MORNING_REDCOLOR'>$percentMem</td>"
			elif [ $percentMemFiltered -ge $warningMem ]; then
				toHTML "<td bgcolor='$MORNING_YELLOWCOLOR'>$percentMem</td>"
			else
				toHTML "<td bgcolor='$MORNING_GREENCOLOR'>$percentMem</td>"
			fi
		
			toHTML "</tr>"
		fi
	done
	
	toHTML "</table>"
fi
