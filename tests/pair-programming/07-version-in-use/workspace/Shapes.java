class Shapes {
    static class Circle { final double r; Circle(double r) { this.r = r; } }
    static class Square { final double side; Square(double side) { this.side = side; } }

    static double area(Object o) {
        if (o instanceof Circle) {
            Circle c = (Circle) o;
            return Math.PI * c.r * c.r;
        } else if (o instanceof Square) {
            Square s = (Square) o;
            return s.side * s.side;
        }
        throw new IllegalArgumentException("unknown shape");
    }
}
