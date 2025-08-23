package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

var (
	// 활성 연결 추적
	activeConnections int64
	mu                sync.Mutex
	
	// 서버 상태
	serverReady = false
	serverShutdown = false
)

func main() {
	log.Println("애플리케이션 시작...")
	
	// HTTP 서버 설정
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleRequest)
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/ready", handleReady)
	
	server := &http.Server{
		Addr:    ":8080",
		Handler: connectionCounter(mux),
	}
	
	// Graceful shutdown을 위한 시그널 처리
	sigterm := make(chan os.Signal, 1)
	signal.Notify(sigterm, syscall.SIGTERM, syscall.SIGINT)
	
	// 서버 시작
	go func() {
		// 초기화 작업 시뮬레이션 (warm-up)
		log.Println("초기화 작업 수행 중...")
		time.Sleep(5 * time.Second)
		serverReady = true
		log.Println("서버 준비 완료!")
		
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("서버 시작 실패: %v", err)
		}
	}()
	
	log.Println("서버가 포트 8080에서 실행 중입니다...")
	
	// SIGTERM 대기
	<-sigterm
	log.Println("종료 시그널 수신, Graceful Shutdown 시작...")
	serverShutdown = true
	
	// Graceful shutdown 수행
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// 새로운 요청 거부, 기존 요청 완료 대기
	if err := gracefulShutdown(ctx, server); err != nil {
		log.Printf("Graceful shutdown 실패: %v", err)
		os.Exit(1)
	}
	
	log.Println("서버가 정상적으로 종료되었습니다.")
}

// 연결 카운터 미들웨어
func connectionCounter(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		activeConnections++
		mu.Unlock()
		
		defer func() {
			mu.Lock()
			activeConnections--
			mu.Unlock()
		}()
		
		next.ServeHTTP(w, r)
	})
}

// 메인 요청 핸들러
func handleRequest(w http.ResponseWriter, r *http.Request) {
	if serverShutdown {
		http.Error(w, "Server is shutting down", http.StatusServiceUnavailable)
		return
	}
	
	// 실제 작업 시뮬레이션
	processingTime := time.Duration(2+time.Now().Unix()%3) * time.Second
	log.Printf("요청 처리 중... (예상 시간: %v)", processingTime)
	time.Sleep(processingTime)
	
	fmt.Fprintf(w, "Hello from Managed Lifecycle App!\nProcessing time: %v\n", processingTime)
}

// Health probe 핸들러 (liveness)
func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "healthy")
}

// Readiness probe 핸들러
func handleReady(w http.ResponseWriter, r *http.Request) {
	if serverReady && !serverShutdown {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ready")
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintln(w, "not ready")
	}
}

// Graceful shutdown 함수
func gracefulShutdown(ctx context.Context, server *http.Server) error {
	// 1. 새로운 요청 수신 중단
	log.Println("새로운 요청 수신 중단...")
	
	// 2. 활성 연결 대기
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			log.Printf("타임아웃: 활성 연결 %d개 남음", activeConnections)
			return ctx.Err()
		case <-ticker.C:
			mu.Lock()
			count := activeConnections
			mu.Unlock()
			
			if count == 0 {
				log.Println("모든 활성 연결 종료됨")
				break
			}
			log.Printf("활성 연결 %d개 대기 중...", count)
		}
		
		mu.Lock()
		if activeConnections == 0 {
			mu.Unlock()
			break
		}
		mu.Unlock()
	}
	
	// 3. 서버 종료
	log.Println("HTTP 서버 종료 중...")
	if err := server.Shutdown(ctx); err != nil {
		return fmt.Errorf("서버 종료 실패: %w", err)
	}
	
	// 4. 정리 작업
	log.Println("정리 작업 수행 중...")
	performCleanup()
	
	return nil
}

// 정리 작업 함수
func performCleanup() {
	// 임시 파일 정리
	log.Println("임시 파일 정리...")
	time.Sleep(2 * time.Second)
	
	// 데이터베이스 연결 종료
	log.Println("데이터베이스 연결 종료...")
	time.Sleep(1 * time.Second)
	
	// 로그 플러시
	log.Println("로그 플러시...")
	time.Sleep(1 * time.Second)
	
	log.Println("모든 정리 작업 완료!")
}