#!/bin/bash

server_root_path=""
residence_save_path=""
world_name=""
world_save_path=""
mca_list="" # (r.x.z.mca r.x.z.mca ...)
cord_list="" # (x1 y1 z1 x2 y2 z2 x1 y1 z1 x2 y2 z2 ...)

# Find Residence plugin save path
# return: residence save path
function get_residence_save_path() {
    residence_save_path=$server_root_path/plugins/Residence/Save/Worlds
    if [ -d "$residence_save_path" ]; then
        printf "找到 Residence 插件存档路径 %s\n" "$residence_save_path"
    else
        printf "错误 - Residence 插件存档路径不存在"
        exit 1
    fi
}

# Find world save path
# return: world save path
function get_world_save_path() {
    # 如果是 world 则路径为 world/
    # 否则路径为 $world_name/DIM-1/
    if [ "$world_name" == "world" ]; then
        world_save_path=$server_root_path/world
    else
        world_save_path=$server_root_path/$world_name/DIM-1
    fi
    if [ -d "$world_save_path" ]; then
        printf "找到世界存档路径 %s\n" "$world_save_path"
    else
        printf "错误 - 世界存档路径不存在"
        exit 1
    fi
}

# Select world
function select_world() {
    local world_list
    world_list=$(ls -1 "${residence_save_path}/" | grep '\.yml$' | tr '\n' ' ')
    local world_list_array
    IFS=' ' read -r -a world_list_array <<<"$world_list"
    local world_list_length=${#world_list_array[@]}
    printf "找到 %s 个世界\n" "$world_list_length"
    for ((i = 0; i < world_list_length; i++)); do
        world_list_array[i]=${world_list_array[i]%.yml}
        world_list_array[i]=${world_list_array[i]#res_}
        printf "%s. %s\n" "$i" "${world_list_array[i]}"
    done
    while true; do
        printf "请输入要操作的世界序号 (0 ~ %d) 或 q 退出\n" "$((world_list_length - 1))"
        printf "> "
        read -r world_index
        if [ "$world_index" -ge 0 ] && [ "$world_index" -lt "$world_list_length" ]; then
            world_name=${world_list_array[world_index]}
            break
        elif [ "$world_index" == "q" ]; then
            printf "退出\n"
            exit 0
        else
            printf "输入错误，请重新输入\n"
            continue
        fi
    done
}

# Write mca file list to csv file with format 'filename, x, z, x, z, \n'
function export_mca_list_to_csv() {
    local mca_list_array
    IFS=' ' read -r -a mca_list_array <<<"$mca_list"
    local mca_list_length=${#mca_list_array[@]}
    echo "file_name,mca_x,mca_z,x1,x2,x3,x4,z1,z2,z3,z4,">mca_list.csv
    for ((i = 0; i < mca_list_length; i++)); do
        local mca_file_name=${mca_list_array[i]}
        local mca_file_name_array
        IFS='.' read -r -a mca_file_name_array <<<"$mca_file_name"
        local x=${mca_file_name_array[1]}
        local z=${mca_file_name_array[2]}
        local x1=$((x * 512))
        local x2=$((x * 512 + 511))
        local x3=$((x * 512))
        local x4=$((x * 512 + 511))
        local z1=$((z * 512))
        local z2=$((z * 512))
        local z3=$((z * 512 + 511))
        local z4=$((z * 512 + 511))
        echo "$mca_file_name,$x,$z,$x1,$x2,$x3,$x4,$z1,$z2,$z3,$z4,">>mca_list.csv
    done
    printf "共 %s 个mca 已导出 mca 文件列表到 mca_list.csv\n" "$mca_list_length"
}

# Generate dynmap areas.yml file
function generate_dynmap_areas() {
    local mca_list_array
    IFS=' ' read -r -a mca_list_array <<<"$mca_list"
    local mca_list_length=${#mca_list_array[@]}
    echo "areas:" >areas.yml
    for ((i = 0; i < mca_list_length; i++)); do
        local mca_file_name=${mca_list_array[i]}
        local mca_file_name_array
        IFS='.' read -r -a mca_file_name_array <<<"$mca_file_name"
        local x=${mca_file_name_array[1]}
        local z=${mca_file_name_array[2]}
        local x1=$((x * 512))
        local x2=$(((x + 1) * 512))
        local x3=$(((x + 1) * 512))
        local x4=$((x * 512))
        local z1=$((z * 512))
        local z2=$((z * 512))
        local z3=$(((z + 1) * 512))
        local z4=$(((z + 1) * 512))
        echo "            area_100$i:" >>areas.yml
        echo "                fillColor: 8421504 # 0x808080" >>areas.yml
        echo "                world: $world_name" >>areas.yml
        echo "                markup: false" >>areas.yml
        echo "                ytop: 64.0" >>areas.yml
        echo "                fillOpacity: 0.3" >>areas.yml
        echo "                x:" >>areas.yml
        echo "                - $x1.0" >>areas.yml
        echo "                - $x2.0" >>areas.yml
        echo "                - $x3.0" >>areas.yml
        echo "                - $x4.0" >>areas.yml
        echo "                strokeWeight: 1" >>areas.yml
        echo "                z:" >>areas.yml
        echo "                - $z1.0" >>areas.yml
        echo "                - $z2.0" >>areas.yml
        echo "                - $z3.0" >>areas.yml
        echo "                - $z4.0" >>areas.yml
        echo "                label: $mca_file_name" >>areas.yml
        echo "                ybottom: 64.0" >>areas.yml
        echo "                strokeColor: 8421504" >>areas.yml
        echo "                strokeOpacity: 1.0" >>areas.yml
    done
    printf "共 %s 个mca 已生成 dynmap areas 到 areas.yml\n" "$mca_list_length"
}

# Delete mca files not in mca_list
function purge_mca_files() {
    local mca_list_array
    IFS=' ' read -r -a mca_list_array <<<"$mca_list"
    local mca_list_length=${#mca_list_array[@]}

    local region_path=$world_save_path/region
    local entitits_path=$world_save_path/entities

    local all_region_mca_files
    all_region_mca_files=$(ls "$region_path" | grep '\.mca$' | tr '\n' ' ')
    local all_entities_mca_files
    all_entities_mca_files=$(ls "$entitits_path" | grep '\.mca$' | tr '\n' ' ')

    local all_region_mca_files_array
    IFS=' ' read -r -a all_region_mca_files_array <<<"$all_region_mca_files"
    local all_region_mca_files_length=${#all_region_mca_files_array[@]}
    printf "找到 %s 个 mca 文件\n" "$all_region_mca_files_length"
    for ((i = 0; i < all_region_mca_files_length; i++)); do
        if [[ ! " ${mca_list_array[*]} " =~ ${all_region_mca_files_array[i]} ]]; then
            printf "删除 mca 文件 %s\n" "${all_region_mca_files_array[i]}"
            rm "$region_path/${all_region_mca_files_array[i]}"
        fi
    done

    local all_entities_mca_files_array
    IFS=' ' read -r -a all_entities_mca_files_array <<<"$all_entities_mca_files"
    local all_entities_mca_files_length=${#all_entities_mca_files_array[@]}
    printf "找到 %s 个 mca 文件\n" "$all_entities_mca_files_length"
    for ((i = 0; i < all_entities_mca_files_length; i++)); do
        if [[ ! " ${mca_list_array[*]} " =~ ${all_entities_mca_files_array[i]} ]]; then
            printf "删除 mca 文件 %s\n" "${all_entities_mca_files_array[i]}"
            rm "$entitits_path/${all_entities_mca_files_array[i]}"
        fi
    done
}

# Select operate
function select_operate() {
    local mca_list_array
    IFS=' ' read -r -a mca_list_array <<<"$mca_list"
    local mca_list_length=${#mca_list_array[@]}
    while true; do
        printf "请输入要操作的类型\n"
        printf "1. 导出 mca 文件列表到 csv\n"
        printf "2. 删除不在 mca 文件列表中的 mca 文件\n"
        printf "3. 导出dynmap areas 到 areas.yml\n"
        printf "> "
        read -r operate_type
        if [ "$operate_type" == "1" ]; then
            export_mca_list_to_csv
            break
        elif [ "$operate_type" == "2" ]; then
            printf "确认操作 y/n\n"
            printf "> "
            read -r confirm
            if [ "$confirm" == "y" ]; then
                get_world_save_path
                purge_mca_files
                break
            else
                printf "取消操作\n"
                break
            fi
        elif [ "$operate_type" == "3" ]; then
            generate_dynmap_areas
            break
        else
            printf "输入错误，请重新输入\n"
            continue
        fi
    done

}

# Parse all 'main: 1575:-64:-2452:2045:319:-1872' in file to '1575 -64 -2452 2045 319 -1872'
# to format 'x1 y1 z1 x2 y2 z2 x1 y1 z1 x2 y2 z2 ...''
function parse_residence_list() {
    local world_save_file_path=$residence_save_path/res_$world_name.yml
    local residence_list
    residence_list=$(grep -oP "main: \K.*" "$world_save_file_path" | tr '\n' ' ')
    local residence_list_array
    IFS=' ' read -r -a residence_list_array <<<"$residence_list"
    local residence_list_length=${#residence_list_array[@]}
    for ((i = 0; i < residence_list_length; i++)); do
        local residence_cord
        residence_cord=$(echo "${residence_list_array[i]}" | tr ':' ' ')
        cord_list="$cord_list $residence_cord"
    done
}

# Cast cordination to mca file name
function cast_cord_to_mca() {
    local cord_list_array
    IFS=' ' read -r -a cord_list_array <<<"$cord_list"
    local cord_list_length=${#cord_list_array[@]}
    for ((i = 0; i < cord_list_length; i += 6)); do
        local x1=${cord_list_array[i]}
        local z1=${cord_list_array[i + 2]}
        local x2=${cord_list_array[i + 3]}
        local z2=${cord_list_array[i + 5]}
        local x1_mca=$((x1 / 512))
        local z1_mca=$((z1 / 512))
        local x2_mca=$((x2 / 512))
        local z2_mca=$((z2 / 512))
        # expand 1 field to each side
        for ((x = x1_mca - 2; x <= x2_mca + 2; x++)); do
            for ((z = z1_mca - 2; z <= z2_mca + 2; z++)); do
                file_name="r.$x.$z.mca"
                # if file not exist in mca_list_result then add it
                if [[ "$mca_list" != *"$file_name"* ]]; then
                    mca_list="$mca_list $file_name"
                fi
            done
        done
    done
}

# Main function
function main() {
    server_root_path=$1

    # Check if server root path is empty
    if [ -z "$server_root_path" ]; then
        echo "Usage: PurgeMca.sh <server_root_path>"
        exit 1
    fi

    # Check if server root path exists
    if [ ! -d "$server_root_path" ]; then
        echo "Server root path does not exist"
        exit 1
    fi

    get_residence_save_path
    while true; do
        select_world
        parse_residence_list
        cast_cord_to_mca
        select_operate
        printf "任务完成 继续或退出 c/q\n"
        printf "> "
        read -r continue_or_quit
        if [ "$continue_or_quit" == "c" ]; then
            clear
            continue
        elif [ "$continue_or_quit" == "q" ]; then
            break
        else
            printf "输入错误，退出\n"
            break
        fi
    done
}

# Call main function
main "$1"

