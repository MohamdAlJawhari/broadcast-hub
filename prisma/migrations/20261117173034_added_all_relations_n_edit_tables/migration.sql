/*
  Warnings:

  - You are about to drop the column `created_at` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `default_country_code` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `password_hash` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `user_name` on the `User` table. All the data in the column will be lost.
  - You are about to drop the `WhatsappSessions` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `attachments` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `broadcast_recipients` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `broadcasts` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `contact_list` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `contacts` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `passwordHash` to the `User` table without a default value. This is not possible if the table is not empty.
  - Added the required column `userName` to the `User` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "User_user_name_idx";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "created_at",
DROP COLUMN "default_country_code",
DROP COLUMN "password_hash",
DROP COLUMN "user_name",
ADD COLUMN     "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "defaultCountryCode" TEXT NOT NULL DEFAULT '+961',
ADD COLUMN     "passwordHash" TEXT NOT NULL,
ADD COLUMN     "userName" TEXT NOT NULL;

-- DropTable
DROP TABLE "WhatsappSessions";

-- DropTable
DROP TABLE "attachments";

-- DropTable
DROP TABLE "broadcast_recipients";

-- DropTable
DROP TABLE "broadcasts";

-- DropTable
DROP TABLE "contact_list";

-- DropTable
DROP TABLE "contacts";

-- CreateTable
CREATE TABLE "WhatsappSession" (
    "id" SERIAL NOT NULL,
    "userId" UUID NOT NULL,
    "state" "ConnectionState" NOT NULL DEFAULT 'DISCONNECTED',
    "credentialsEncrypted" TEXT,
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WhatsappSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContactList" (
    "id" SERIAL NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContactList_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Contact" (
    "id" SERIAL NOT NULL,
    "listId" INTEGER NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "isValid" BOOLEAN NOT NULL DEFAULT true,
    "customFields" JSONB,

    CONSTRAINT "Contact_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Attachment" (
    "id" SERIAL NOT NULL,
    "userId" UUID NOT NULL,
    "storagePath" TEXT NOT NULL,
    "attachmentType" TEXT NOT NULL,
    "originalName" TEXT NOT NULL,
    "sizeBytes" BIGINT NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Attachment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Broadcast" (
    "id" SERIAL NOT NULL,
    "userId" UUID NOT NULL,
    "listId" INTEGER NOT NULL,
    "messageText" TEXT NOT NULL,
    "attachmentId" INTEGER,
    "attachmentType" TEXT,
    "status" "BroadcastStatus" NOT NULL,
    "pauseReason" TEXT,
    "startedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMPTZ,

    CONSTRAINT "Broadcast_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BroadcastRecipient" (
    "id" SERIAL NOT NULL,
    "broadcastId" INTEGER NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "customFields" JSONB,
    "status" "RecipientStatus" NOT NULL DEFAULT 'PENDING',
    "errorCategory" TEXT,
    "failureReason" TEXT,
    "processedAt" TIMESTAMPTZ,

    CONSTRAINT "BroadcastRecipient_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "WhatsappSession_userId_key" ON "WhatsappSession"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "ContactList_userId_name_key" ON "ContactList"("userId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "Contact_listId_phoneNumber_key" ON "Contact"("listId", "phoneNumber");

-- CreateIndex
CREATE INDEX "Attachment_userId_idx" ON "Attachment"("userId");

-- CreateIndex
CREATE INDEX "Broadcast_userId_idx" ON "Broadcast"("userId");

-- CreateIndex
CREATE INDEX "Broadcast_listId_idx" ON "Broadcast"("listId");

-- CreateIndex
CREATE INDEX "Broadcast_attachmentId_idx" ON "Broadcast"("attachmentId");

-- CreateIndex
CREATE INDEX "BroadcastRecipient_broadcastId_idx" ON "BroadcastRecipient"("broadcastId");

-- CreateIndex
CREATE INDEX "User_userName_idx" ON "User"("userName");

-- AddForeignKey
ALTER TABLE "WhatsappSession" ADD CONSTRAINT "WhatsappSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ContactList" ADD CONSTRAINT "ContactList_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Contact" ADD CONSTRAINT "Contact_listId_fkey" FOREIGN KEY ("listId") REFERENCES "ContactList"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Attachment" ADD CONSTRAINT "Attachment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Broadcast" ADD CONSTRAINT "Broadcast_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Broadcast" ADD CONSTRAINT "Broadcast_listId_fkey" FOREIGN KEY ("listId") REFERENCES "ContactList"("id") ON DELETE NO ACTION ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Broadcast" ADD CONSTRAINT "Broadcast_attachmentId_fkey" FOREIGN KEY ("attachmentId") REFERENCES "Attachment"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BroadcastRecipient" ADD CONSTRAINT "BroadcastRecipient_broadcastId_fkey" FOREIGN KEY ("broadcastId") REFERENCES "Broadcast"("id") ON DELETE CASCADE ON UPDATE CASCADE;
