package installer

import (
	"context"
	"errors"
	"os/exec"
	"time"
)

func Install_Marzban() error {
	ctx, cencel := context.WithTimeout(context.Background(), 2 * time.Minute)
	defer cencel()

	cmd := exec.CommandContext(ctx, "sudo", "bash", "-c", `$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh) @ install`)
	
	_, err := cmd.CombinedOutput()
	if err != nil {
		return errors.New("marzban install error") 
	}

	return nil
}
