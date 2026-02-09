#!/bin/bash
# 158.130.4.229:7770
# Get the server's public IP address
gdown 1Um4QLxi_bGv5bP6kt83Ke0lNjuV9Tm0P

docker run -d --name=wikipedia --volume=<your-path-to-downloaded-folder>/:/data -p 8888:80 ghcr.io/kiwix/kiwix-serve:3.3.0 wikipedia_en_all_maxi_2022-05.zim