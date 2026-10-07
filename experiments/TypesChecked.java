// The same signature as Pricing.total, called the way the
// Python experiment calls it.
class TypesChecked {

    static long total(long unitPrice, int quantity) {
        return unitPrice * quantity;
    }

    public static void main(String[] args) {
        System.out.println(total("5", 3));
    }
}
