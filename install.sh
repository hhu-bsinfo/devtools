#!/bin/bash

INSTALL_DIR="$HOME/.dpm"

set -e

mkdir -p "${INSTALL_DIR}"

update()
{
	echo ":: performing update"
	git -C "${INSTALL_DIR}" pull origin master --quiet
	echo ":: update finished"
}

install()
{
	echo ":: installing into ${INSTALL_DIR}"
	git clone git@github.com:hhu-bsinfo/dxdevtools.git "${INSTALL_DIR}" --quiet
	
	echo ":: setting execute permissions"
	chmod +x "${INSTALL_DIR}/dpm"

	echo ""
	echo "  -----------------------------------------------------------------------------"
	echo "  |                                                                           |"
	echo "  | To complete the installation add the following line to your .bashrc file: |"
	echo "  |                                                                           |"
	echo "  |   export PATH=\"\$PATH:${INSTALL_DIR}\"                                |"
	echo "  |                                                                           |"
	echo "  -----------------------------------------------------------------------------"
	echo ""
}


if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
  install
else
  update
fi
