package replacer

import (
	"io"
	"os"
)

func Replace_xray() error {
	dstPath := "/var/lib/marzban/xray_config.json"
	srcPath := "xray_config.json"

	src, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	defer src.Close()

	dst, err := os.Open(dstPath)
	if err != nil {
		return err
	}
	defer dst.Close()

	_, err = io.Copy(dst, src)
	if err != nil {
		return err
	}

	return nil
}

func Replace_env() error {
	dstPath := "/opt/marzban/.env"
	srcPath := ".env"

	src, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	defer src.Close()

	dst, err := os.Open(dstPath)
	if err != nil {
		return err
	}
	defer dst.Close()

	_, err = io.Copy(dst, src)
	if err != nil {
		return err
	}

	return nil
}
