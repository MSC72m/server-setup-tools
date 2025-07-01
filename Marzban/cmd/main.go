package main

import (
	"Marzban/client"
	"Marzban/installer"
	"Marzban/replacer"
	"fmt"
	"log"
)

func main() {
	err := installer.Install_Marzban()
	if err != nil {
		log.Println("Instalation Error", err)
	}

	err = replacer.Replace_xray()
	if err != nil {
		log.Println("Configuration Error", err)
	}

	err = replacer.Replace_env()
	if err != nil {
		log.Println("Configuration Error", err)
	}

	panel := client.NewMarzbanClient()
	resp, err := panel.CreateMarzbanUser("admin")
	if err != nil {
		log.Println("User Inbound Error", err)
	}

	fmt.Println(resp.Links)
}
