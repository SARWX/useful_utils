#/bin/bash

ANNOTATIONS_FILE="debian/config/annotations.astra"

############################## CHANGE VALUES HERE ##############################
configs_to_delete=("

")

aufs_configs=$(grep "CONFIG_AUFS_" $ANNOTATIONS_FILE | awk '{print $1}' )
configs_to_delete="${configs_to_delete} ${aufs_configs}"


declare -A renamed_configs
                # old name                # new name
renamed_configs["CONFIG_CPU_SRSO"]="CONFIG_MITIGATION_SRSO"
############################## CHANGE VALUES HERE ##############################


############################## DELETE SECTION ##############################
for config in $configs_to_delete
do
        python3 debian/scripts/generate-config/annotations --config $config --file $ANNOTATIONS_FILE --write 'null'
        echo "$config was deleted"
done
############################## DELETE SECTION ##############################


############################## RENAME SECTION ##############################
for old_name in "${!renamed_configs[@]}"; do
        new_name="${renamed_configs[$old_name]}"
        sed -i -E "s/^$old_name /$new_name /g" "$ANNOTATIONS_FILE" &&
                echo "$old_name was renamed to $new_name"
done
############################## RENAME SECTION ##############################


############################ MAKE PRETTY SECTION ############################
python3 debian/scripts/generate-config/annotations --file $ANNOTATIONS_FILE --config FOO_CONFIG --write 'null'
############################ MAKE PRETTY SECTION ############################
