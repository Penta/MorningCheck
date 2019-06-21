#! /bin/bash
#
# Module pour le morning check permettant de vérifier l'état
# des services sur les machines.
# Ce script utilise le retour de la commande systemctl (systemd).
#
# Par Andy Esnard - v1.1 - 01/03/2019

# Vérification si le script est lancé directement
if [ -z "$MORNING_CHECK" ]; then
	echo "Please do not start this module directly! Use the morning check script instead."
	exit 1
fi

# Path du fichier de la liste des services par machine
fileList="$(loadConf "fileList" "$MORNING_LISTDIR/service.txt")"

echo "Checking the services from $fileList..."

# Si le fichier de liste n'existe pas
if [ ! -f $fileList ]; then
	echo "ERROR! The list file does not exist."
fi

serviceList=()
index=0

# On lit le contenu du fichier et on le met dans un array
while read line; do
	if ! [[ $line = \#* ]]; then
		if ! [ -z "$line" ]; then
			serviceList[$index]="$line"
			index=$(($index+1))
		fi
	fi
done < $fileList

# Si le contenu du fichier est vide
if [ ${#serviceList[@]} -eq 0 ]; then
	echo "ERROR! The list file is empty."
else
	toHTML "<h2>Services check:</h2>"
	
	toHTML "<table>"
	toHTML "<tr><b><th>Machine</th><th colspan='8'>Services</th></b></tr>"

	# Pour chaque ligne dans le fichier de liste
	for service in "${serviceList[@]}"; do
		servicesString=$(echo ${service#*:}) # On récupère la partie de la ligne après les ':' (deux points) 
		machine=$(echo ${service%:*}) # On récupère la partie de la ligne avant les ':' (deux points) 

		# Si la liste des service n'est pas vide
		if [ ! -z "$servicesString" -a "$servicesString" != " " ]; then
			if [ "$machine" = "localhost" ]; then # Si on est en local
				toHTML "<tr><td>$HOSTNAME</td>"
			else
				toHTML "<tr><td>$machine</td>"
			fi
			
			# On remplace les virgules par des espaces (plus simple pour la boucle for)
			servicesString=$(echo "$servicesString" | tr ',' ' ')

			# Pour chaque services donnés pour une machine
			for service in $servicesString; do
				if [ ! -z "$servicesString" ]; then
					if [ "$machine" = "localhost" ]; then # Si c'est la machine locale
						result=$(systemctl status $service | grep 'Active:')
					else # Sinon, on passe par SSH
						result=$(ssh -p $MORNING_SSHPORT -l $MORNING_SSHUSER -q $machine systemctl status $service | grep 'Active:')
					fi

					# Si le résultat est vide
					if [ -z "$result" ]; then
						toHTML "<td bgcolor='$MORNING_REDCOLOR'>$service</td>"
					else # Sinon, si on a un résultat
						if [[ $result =~ .*'active (running)'* ]]; then # Si le résultat et en active/running
							toHTML "<td bgcolor='$MORNING_GREENCOLOR'>$service</td>"
						else # Si le service est dans un autre état
							toHTML "<td bgcolor='$MORNING_REDCOLOR'>$service</td>"
						fi
					fi
				fi
			done
			
			toHTML "</tr>"
		fi
	done

	toHTML "</table>"
fi
