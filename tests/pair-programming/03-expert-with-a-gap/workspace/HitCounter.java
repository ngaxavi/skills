public class HitCounter {
    private volatile int hits = 0;

    public void hit() {
        hits++;
    }

    public int hits() {
        return hits;
    }
}
