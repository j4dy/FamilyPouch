import '../models/user_role.dart';
import '../models/payment_source.dart';
import '../models/claim_status.dart';
import '../models/receipt_item.dart';
import '../models/expense.dart';
import '../models/cash_topup.dart';
import '../models/reimbursement_claim.dart';
import '../models/settlement_cycle.dart';

class MockSeedData {
  static List<SettlementCycle> get initialCycles => [
        SettlementCycle(
          id: 'cycle-aug-2026',
          title: 'August 2026 (Current Cycle)',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          isClosed: false,
        ),
        SettlementCycle(
          id: 'cycle-jul-2026',
          title: 'July 2026 (Settled)',
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 7, 31),
          isClosed: true,
          closedAt: DateTime(2026, 8, 1, 20, 0),
          closedBy: UserRole.mother,
        ),
      ];

  static List<CashTopUp> get initialTopUps => [
        CashTopUp(
          id: 'topup-1',
          disbursedBy: UserRole.mother,
          amount: 500.0,
          date: DateTime(2026, 8, 1, 10, 0),
          note: 'Monthly grocery cash float top-up from Joint Account',
        ),
        CashTopUp(
          id: 'topup-2',
          disbursedBy: UserRole.father,
          amount: 300.0,
          date: DateTime(2026, 8, 15, 14, 30),
          note: 'Mid-month grocery float top-up',
        ),
      ];

  static List<Expense> get initialExpenses => [
        // 1. Mother - Joint Account
        Expense(
          id: 'exp-1',
          payer: UserRole.mother,
          amount: 795.00,
          date: DateTime(2026, 8, 5, 16, 20),
          merchant: 'CLP Power Hong Kong',
          category: 'Utilities',
          description: 'Electricity bill for July/August',
          paymentSource: PaymentSource.jointAccount,
          claimStatus: ClaimStatus.notApplicable,
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'Basic Electricity Charge', price: 650.0),
            ReceiptItem(name: 'Fuel Adjustment', price: 195.0),
            ReceiptItem(name: 'Govt Subsidy', price: -50.0),
          ],
        ),

        // 2. Mother - Out-of-Pocket
        Expense(
          id: 'exp-2',
          payer: UserRole.mother,
          amount: 450.00,
          date: DateTime(2026, 8, 12, 11, 0),
          merchant: 'Little Champions Academy',
          category: 'Kids & Education',
          description: 'Kids weekend swimming & piano lesson fees',
          paymentSource: PaymentSource.outOfPocket,
          claimStatus: ClaimStatus.unclaimed,
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'Swimming Lesson (4 sessions)', price: 300.0),
            ReceiptItem(name: 'Piano Practice Sheet', price: 150.0),
          ],
        ),

        // 3. Father - Joint Account
        Expense(
          id: 'exp-3',
          payer: UserRole.father,
          amount: 340.00,
          date: DateTime(2026, 8, 18, 19, 45),
          merchant: 'DON DON DONKI',
          category: 'Groceries',
          description: 'Family weekend dinner groceries & Japanese snacks',
          paymentSource: PaymentSource.jointAccount,
          claimStatus: ClaimStatus.notApplicable,
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'Wagyu Beef Cut', price: 180.0),
            ReceiptItem(name: 'Japanese Somen Noodles', price: 60.0),
            ReceiptItem(name: 'Matcha Snacks & Drinks', price: 100.0),
          ],
        ),

        // 4. Father - Out-of-Pocket
        Expense(
          id: 'exp-4',
          payer: UserRole.father,
          amount: 220.00,
          date: DateTime(2026, 8, 20, 15, 30),
          merchant: 'Hong Kong Air Conditioning Care',
          category: 'Home Maintenance',
          description: 'Living room air conditioning filter replacement',
          paymentSource: PaymentSource.outOfPocket,
          claimStatus: ClaimStatus.unclaimed,
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'HEPA Filter Replacement', price: 160.0),
            ReceiptItem(name: 'Cleaning Spray', price: 60.0),
          ],
        ),

        // 5. Helper - Grocery Cash Float
        Expense(
          id: 'exp-5',
          payer: UserRole.helper,
          amount: 178.50,
          date: DateTime(2026, 8, 22, 10, 15),
          merchant: 'Wellcome Supermarket',
          category: 'Groceries',
          description: 'Weekly fresh groceries, milk, eggs & rice',
          paymentSource: PaymentSource.groceryCash,
          claimStatus: ClaimStatus.notApplicable,
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'Japanese Fresh Eggs 10s', price: 28.50),
            ReceiptItem(name: 'Organic Fresh Milk 1L', price: 46.00, quantity: 2),
            ReceiptItem(name: 'Premium Thai Jasmine Rice', price: 68.00),
            ReceiptItem(name: 'Australian Avocados 3s', price: 24.00),
            ReceiptItem(name: 'Kitchen Paper Towel 4s', price: 22.00),
          ],
        ),

        // 6. Helper - Grocery Cash Float
        Expense(
          id: 'exp-6',
          payer: UserRole.helper,
          amount: 85.00,
          date: DateTime(2026, 8, 25, 9, 30),
          merchant: 'Wanchai Wet Market',
          category: 'Groceries',
          description: 'Fresh vegetables, tofu, and pork for dinners',
          paymentSource: PaymentSource.groceryCash,
          claimStatus: ClaimStatus.notApplicable,
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'Choy Sum & Kai Lan', price: 32.0),
            ReceiptItem(name: 'Fresh Pork Loin', price: 40.0),
            ReceiptItem(name: 'Organic Tofu 2 packs', price: 13.0),
          ],
        ),

        // 7. Helper - Out-of-Pocket (Emergency pharmacy purchase, pending claim)
        Expense(
          id: 'exp-7',
          payer: UserRole.helper,
          amount: 87.50,
          date: DateTime(2026, 8, 27, 11, 20),
          merchant: 'Watsons Pharmacy',
          category: 'Health & Medical',
          description: 'Emergency fever patches, Panadol and sanitizer for kids',
          paymentSource: PaymentSource.outOfPocket,
          claimStatus: ClaimStatus.pendingApproval,
          claimId: 'claim-1',
          cycleId: 'cycle-aug-2026',
          itemizedDetails: [
            ReceiptItem(name: 'Panadol Extra Caplets 24s', price: 58.00),
            ReceiptItem(name: 'Alcohol Hand Sanitizer 500ml', price: 29.50),
          ],
        ),
      ];

  static List<ReimbursementClaim> get initialClaims => [
        ReimbursementClaim(
          id: 'claim-1',
          claimant: UserRole.helper,
          expenseIds: ['exp-7'],
          totalAmount: 87.50,
          submittedAt: DateTime(2026, 8, 27, 12, 0),
          status: ClaimStatus.pendingApproval,
          notes: 'Paid personally with Visa when grocery cash was left at home.',
        ),
        ReimbursementClaim(
          id: 'claim-past-1',
          claimant: UserRole.helper,
          expenseIds: [],
          totalAmount: 120.00,
          submittedAt: DateTime(2026, 7, 28, 14, 0),
          settledAt: DateTime(2026, 7, 29, 18, 30),
          settledBy: UserRole.mother,
          transferReference: 'FPS-REF-9920148',
          status: ClaimStatus.settled,
          notes: 'Spare house key duplicates paid out-of-pocket.',
        ),
      ];
}
