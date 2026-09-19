-- AlterTable
ALTER TABLE "users" ADD COLUMN "token_version" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "billing_items" ADD COLUMN "snoozed_until" TIMESTAMP(3);
ALTER TABLE "billing_items" ADD COLUMN "paid_at" TIMESTAMP(3);
ALTER TABLE "study_schedules" ADD COLUMN "last_notified_at" TIMESTAMP(3);
ALTER TABLE "notification_logs" ADD COLUMN "message" TEXT;

-- CreateTable
CREATE TABLE "price_history" (
    "id" TEXT NOT NULL,
    "billing_item_id" TEXT NOT NULL,
    "old_amount" DECIMAL(65,30) NOT NULL,
    "new_amount" DECIMAL(65,30) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "price_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "price_histories_billingItemId_idx" ON "price_history"("billing_item_id");

-- AddForeignKey
ALTER TABLE "price_history" ADD CONSTRAINT "price_history_billing_item_id_fkey" FOREIGN KEY ("billing_item_id") REFERENCES "billing_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;
