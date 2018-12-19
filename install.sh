#!/bin/bash

INSTALL_DIR="$HOME/.dru"

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
	chmod +x "${INSTALL_DIR}/dru"

	echo ""
	echo "  -----------------------------------------------------------------------------"
	echo "  |                                                                           |"
	echo "  | To complete the installation add the following line to your .bashrc file: |"
	echo "  |                                                                           |"
	echo "  |   export PATH=\"\$PATH:${INSTALL_DIR}\"                                |"
	echo "  |                                                                           |"
	echo "  -----------------------------------------------------------------------------"
	echo ""
	
	read -p ":: add line to .bashrc now? [y|N] " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "" >> "${HOME}/.bashrc"
		echo "# DX Project Manager" >> "${HOME}/.bashrc"
		echo "export PATH=\"\$PATH:${INSTALL_DIR}\"" >> "${HOME}/.bashrc"
	fi
	
	echo ""
}


if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
  install
else
  update
fi
