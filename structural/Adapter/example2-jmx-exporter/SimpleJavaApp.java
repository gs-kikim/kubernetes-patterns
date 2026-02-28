import javax.management.*;
import java.lang.management.ManagementFactory;
import java.util.Random;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Simple Java Application exposing JMX metrics
 * Simulates a legacy application that uses JMX for monitoring
 */
public class SimpleJavaApp implements SimpleJavaAppMBean {
    private final AtomicLong requestCount = new AtomicLong(0);
    private final AtomicLong errorCount = new AtomicLong(0);
    private final Random random = new Random();
    private volatile long lastResponseTime = 0;

    public static void main(String[] args) throws Exception {
        SimpleJavaApp app = new SimpleJavaApp();
        app.registerMBean();
        app.run();
    }

    private void registerMBean() throws Exception {
        MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
        ObjectName name = new ObjectName("com.example:type=SimpleJavaApp");
        mbs.registerMBean(this, name);
        System.out.println("JMX MBean registered: " + name);
    }

    private void run() throws InterruptedException {
        System.out.println("Simple Java App started");
        System.out.println("Simulating work and exposing JMX metrics...");

        while (true) {
            simulateWork();
            Thread.sleep(2000);
        }
    }

    private void simulateWork() {
        long start = System.currentTimeMillis();

        try {
            // Simulate some work
            Thread.sleep(random.nextInt(100) + 10);

            // 10% chance of error
            if (random.nextInt(10) == 0) {
                errorCount.incrementAndGet();
                System.out.println("Simulated error occurred");
            }

            requestCount.incrementAndGet();
            lastResponseTime = System.currentTimeMillis() - start;

            System.out.printf("Request processed: count=%d, errors=%d, responseTime=%dms%n",
                    requestCount.get(), errorCount.get(), lastResponseTime);

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    @Override
    public long getRequestCount() {
        return requestCount.get();
    }

    @Override
    public long getErrorCount() {
        return errorCount.get();
    }

    @Override
    public long getLastResponseTime() {
        return lastResponseTime;
    }

    @Override
    public double getErrorRate() {
        long requests = requestCount.get();
        if (requests == 0) return 0.0;
        return (double) errorCount.get() / requests * 100.0;
    }
}

/**
 * MBean interface - defines what metrics are exposed via JMX
 */
interface SimpleJavaAppMBean {
    long getRequestCount();
    long getErrorCount();
    long getLastResponseTime();
    double getErrorRate();
}
