package main

import (
	"errors"
	"io"
	"log"
	"os"

	"github.com/pkg/sftp"
)

type stdio struct{}

func (stdio) Read(p []byte) (int, error)  { return os.Stdin.Read(p) }
func (stdio) Write(p []byte) (int, error) { return os.Stdout.Write(p) }
func (stdio) Close() error                { return nil }

func main() {
	startDirectory := "/sdcard"
	if override := os.Getenv("DROPBEAR_KSU_SFTP_START_DIR"); override != "" {
		startDirectory = override
	}

	server, err := sftp.NewServer(
		stdio{},
		sftp.WithServerWorkingDirectory(startDirectory),
	)
	if err != nil {
		log.Printf("sftp-server: initialize: %v", err)
		os.Exit(1)
	}

	err = server.Serve()
	closeErr := server.Close()
	if err != nil && !errors.Is(err, io.EOF) {
		log.Printf("sftp-server: serve: %v", err)
		os.Exit(1)
	}
	if closeErr != nil {
		log.Printf("sftp-server: close: %v", closeErr)
		os.Exit(1)
	}
}
