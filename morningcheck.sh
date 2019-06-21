#! /bin/bash
#
# Script de morning check pour environnements UNIX.
#
# Pour configurer le script, veuillez vous rendre dans
# le répertoire ./conf/, rien ne devrait être configurable
# directement dans ce script.
#
# Dans le répertoire ./lists/ vous trouverez les listes des
# élements à monitorer.
#
# Si vous voulez rajouter un module au morning check, placez
# son script dans le répertoire ./modules/ et allez rajouter sa
# ligne dans le fichier ./conf/modules.cfg à l'emplacement
# souhaité.
#
# Par Andy Esnard - v1.1.2 - 20/03/2019

# Génération du path pour le fichier HTML
BASEDIR=$(dirname "$0")
BASEDIR=$(realpath "$BASEDIR")
file="morningcheck.html"

export MORNING_TEMPDIR="$HOME/.morning"
export MORNING_HTMLFILE="$MORNING_TEMPDIR/$file"

# Fonction permettant d'écrire dans le fichier HTML
function toHTML () {
	echo "$1" >> $MORNING_HTMLFILE
}

# Fonction permettant de charger une valeur dans un fichier de configuration
function loadConf () {
	# Petite condition pour changer quelques paramètres entre l'utilisation de cette fonction par le script principal ou par un module
	if [ ! "$isMain" = "true" ]; then
		configFile="$MORNING_MODCONFDIR/$MORNING_MODULENAME.cfg"
	else
		configFile="$MORNING_CONFDIR/morningcheck.cfg"
	fi

	defaultMessage=$2 # $2 étant la valeur par défaut fourni par le module

	# Si le fichier existe
	if [ -f $configFile ]; then
        	stringConf=$(cat $configFile | egrep -v "^\s*(#|$)" | grep "$1") # On récupère les lignes non commentées contenant le nom de valeur demandé
		nbLigne=$(echo $stringConf | wc -l) # Le nombre de ligne de résultat

		# Si il n'y a qu'une ligne
		if [ $nbLigne -eq 1 ]; then 
			if [ ! -z "$stringConf" ]; then
				result=$(echo ${stringConf#*=} | tr -d '\r') # On récupère la valeur
			else # On retourne une erreur ou la valeur par défaut
				result="$defaultMessage"
			fi
		else
			result="$defaultMessage"
		fi
	else
		result="$defaultMessage"
	fi

	# On renvoie le résultat de la commande
	echo "$result"
}

# Fonction permettant d'exporter la configuration du script pour la rendre lisible par les modules.
function export_config () {
	export MORNING_URLLIST="$BASEDIR/urllist.txt"

	export MORNING_GREENCOLOR="#00FF00"
	export MORNING_YELLOWCOLOR="#FFFF00"
	export MORNING_REDCOLOR="#FF0000"
	export MORNING_GREYCOLOR="#787878"

	export MORNING_LISTDIR="$BASEDIR/lists"
	export MORNING_RSCDIR="$BASEDIR/resources"
	export MORNING_CONFDIR="$BASEDIR/conf"
	export MORNING_MODCONFDIR="$BASEDIR/conf/modules"
	export MORNING_BASEDIR="$BASEDIR"

	export MORNING_TEMPDIR="$HOME/.morning"
	export MORNING_HTMLFILE="$MORNING_TEMPDIR/$file"

	export MORNING_MODULENAME="$module"
	
	export MORNING_CHECK="true"

	# Conf SSH
	export MORNING_SSHUSER=$(loadConf "SSHuser" "$USER")
	export MORNING_SSHPORT=$(loadConf "SSHport" "22")
	export MORNING_SSHTIMEOUT=$(loadConf "SSHtimeout" "10")

	# On exporte aussi des fonctions de ce script
	export -f toHTML
	export -f loadConf
}

# Fonction chargeant les modules
function load_modules () {
	echo "[main] Loading modules..."

	# Fichier de configuration contenant la liste des modules à exécuter
	moduleFile="$MORNING_CONFDIR/modules.cfg"

	# Si le fichier de configuration n'existe pas
	if [ ! -f $moduleFile ]; then
		echo "[main] $moduleFile not found! Script halted."
		rm $MORNING_HTMLFILE
		exit 1 # On quitte le script de morning check
	fi

	moduleList=()
	index=0

	# On lit le fichier de config et on récupère son contenu sous forme d'array
	while read line; do
		if ! [[ $line = \#* ]]; then
			if ! [ -z "$line" ]; then
				moduleList[$index]="$line"
				index=$(($index+1))
			fi
		fi
	done < $moduleFile

	# Pour chaque module dans l'array
	for module in "${moduleList[@]}"; do
		script="$BASEDIR/modules/$module.sh" # Génération du path du fichier de script du module

		# Si le fichier de script du module existe
		if [ -f $script ]; then
			export_config # On exporte la conf avant chaque lancement de module si jamais un module s'est amusé à la changer entre temps
			bash "$script" 2>&1 | sed -e "s/^/\[$module\] /" # On execute le module
			toHTML "<br />"
		else # Si le fichier de script du module n'existe pas
			echo "[main] The module $module.sh does not exist."
		fi
	done
}

# Variable utilisée pour dire à la fonction loadConf que ce script est le principal
isMain="true"

# On exporte la conf via la commande ci-dessus
export_config

# Si le fichier de conf principal existe
if [ -f "$MORNING_CONFDIR/morningcheck.cfg" ]; then
	#Alors on charge les variables importantes au fonctionnement du script
	title=$(loadConf "title" "Morning Check")
	sender=$(loadConf "sender" "$HOSTNAME@morningcheck.local")

	# Pour la liste des destinataires, on remplace les virgules par des espaces (c'est ce que l'exécutable sendmail attend).
	receiver=$(loadConf "receiver" "[MORNINGCHECK_ERRORCONF]")
	receiver=$(echo "$receiver" | tr ',' ' ')

	if [ "$receiver" = "[MORNINGCHECK_ERRORCONF]" ]; then
		echo "[main] Bad configuration (no receiver specified)! The script is now halted."
		exit 1 # On quitte le script si jamais une variable n'a pas été chargée
	fi
else # Si le fichier de configuration principal n'existe pas.
	echo "[main] Configuration file $MORNING_CONFDIR/morningcheck.cfg is not found! Script halted."
	exit 1
fi

echo "[main] Working dir: $MORNING_BASEDIR"
echo "[main] Temp dir:    $MORNING_TEMPDIR"

# Si le fichier HTML n'a pas été supprimé à la dernière exécution
if [ -d $MORNING_TEMPDIR ]; then
        rm -rf $MORNING_TEMPDIR
fi

# Si le fichier HTML n'a pas été supprimé à la dernière exécution
if [ -f $MORNING_HTMLFILE ]; then
	rm $MORNING_HTMLFILE
fi

# Création du fichier HTML vide
mkdir $MORNING_TEMPDIR
touch $MORNING_HTMLFILE

# Création de son contenu
toHTML "<html><head><style>"

# On y injecte le fichier CSS
cat "$MORNING_RSCDIR/style.css" >> $MORNING_HTMLFILE

toHTML "</style></head><body>"
toHTML "<h1 style='text-align: center;'>$title</h1>"

# On charge les modules via la fonction
load_modules

# On y met le pied de page avec les infos d'exécution
toHTML "<p style='text-align: center;'><i>Morning check executed by <b>$USER</b> on <b>$HOSTNAME</b> (<i>$MORNING_BASEDIR</i>).</i></p>"
toHTML "</body></html>"

(
	# Metadonnées du mail.
	echo "From: $sender"
	echo "To: $receiver"
	echo "Subject: $title"
	echo "MIME-Version: 1.0"
	echo "Content-Type: text/html"
	echo "Content-Disposition: inline"

	# On y injecte notre fichier HTML
	cat $MORNING_HTMLFILE
) | /usr/sbin/sendmail -v $receiver 2>&1 | sed -e "s/^/\[sendmail\] /" # Et on envoie le mail.

echo "[main] Message sent to $receiver."

# On supprime les fichiers temporaires une fois que le script a été exécuté
rm -rf $MORNING_TEMPDIR
