#!/bin/bash

# Удаляем локальные ветки
git branch | grep -E '(from|final-[0-9]+\.[0-9]+\.?[0-9]*_rebase|remote_(from|to))_[0-9]{2}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$' | while read -r branch; do
    git branch -D "${branch#* }"  # Удаляем символ '*' и пробел для текущей ветки
done
