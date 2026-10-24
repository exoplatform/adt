// Command adt-web is the ADT dashboard.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/gitx"
	"github.com/exoplatform/adt/web/internal/view"
	// Pages and REST endpoints register themselves from init().
	"github.com/exoplatform/adt/web/internal/pages"
	_ "github.com/exoplatform/adt/web/internal/rest"
)

func main() {
	cfg := config.FromEnv()
	if cfg.DataDir == "" {
		log.Fatal("ADT_DATA is not set")
	}
	view.SetAssetDir(cfg.StaticDir)
	if err := view.ParseAll(); err != nil {
		log.Fatal(err)
	}
	l, where, err := listen(cfg)
	if err != nil {
		log.Fatal(err)
	}
	// The branch lists and the git activity take seconds to compute: do it now, in the background, not on the
	// first visitor's request.
	go func() {
		gitx.Warm(cfg.DataDir)
		pages.WarmGitActivity(cfg.DataDir)
		pages.WarmCrowdinHealth(cfg.DataDir)
	}()
	srv := &http.Server{
		Handler: app.New(cfg).Handler(),
		// Slow-client protection. No overall write timeout: log downloads can be large.
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}

	// systemd stops the service with SIGTERM: finish the running requests, then remove the socket.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	done := make(chan struct{})
	go func() {
		defer close(done)
		<-stop
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("shutdown: %v", err)
		}
	}()

	log.Printf("adt-web listening on %s (dev=%v, data=%s)", where, cfg.DevMode, cfg.DataDir)
	if err := srv.Serve(l); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
	<-done
	log.Print("adt-web stopped")
}
