#! /bin/bash
#
# Module pour le morning check permettant de vérifier un URL
# selon son code HTTP.
#
# Par Andy Esnard - SOGETI - 12/03/2019

# Vérification si le script est lancé directement
if [ -z "$MORNING_CHECK" ]; then
	echo "Please do not start this module directly! Use the morning check script instead."
	exit 1
fi

# Path du fichier de la liste des URL
fileList="$(loadConf "fileList" "$MORNING_LISTDIR/url.txt")"

timeout="$(loadConf "timeout" "5")"

echo "Checking the URL from $fileList..."

# Si le fichier de liste n'existe pas
if [ ! -f $fileList ]; then
	echo "ERROR! The list file does not exist."
fi

urlList=()
index=0

# On lit le contenu du fichier et on le met dans un array
while read line; do
	if ! [[ $line = \#* ]]; then
		if ! [ -z "$line" ]; then
			urlList[$index]="$line"
			index=$(($index+1))
		fi
	fi
done < $fileList

# Si le contenu du fichier est vide
if [ ${#urlList[@]} -eq 0 ]; then
	echo "ERROR! the list file is empty."
else # Sinon
	expectedCode='200' # Code HTTP attendu par défaut

	toHTML "<h2>URL check:</h2>"
	
	toHTML "<table>"
	toHTML "<tr><b><th>URL</th> <th>Code</th> <th>Status</th></b></tr>"

	# Pour chaque ligne dans le fichier de liste
	for url in "${urlList[@]}"; do
		if [[ $url == :* ]]; then # Si la ligne commence par deux points (syntaxe pour précise le code HTTP attendu pour les prochains URL)
			# On récupère le code attendu dans le fichier de liste des URL
			expectedCode=$(echo "$url" | cut -c 2-)
		else # Sinon, on la considere comme un URL
			# On récupère le code HTTP de l'URL
			result=$(curl -o /dev/null --connect-timeout $timeout --max-time 15 --silent --head --write-out '%{http_code}\n' $url)

			toHTML "<tr>"

			# Si on a bien le résultat escompté
			if [ $result -eq $expectedCode ]; then
				toHTML "<td><a href='$url'>$url</a></td><td>$result</td><td bgcolor='$MORNING_GREENCOLOR'>OK</td>"
			else # Sinon
				toHTML "<td><a href='$url'>$url</a></td><td>$result</td><td bgcolor='$MORNING_REDCOLOR'>ERROR (Expecting $expectedCode)</td>"
			fi

			toHTML "</tr>"
		fi
	done

	toHTML "</table>"
fi
