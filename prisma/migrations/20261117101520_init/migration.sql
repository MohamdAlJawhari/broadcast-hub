-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'BLOCKED');

-- CreateEnum
CREATE TYPE "ConnectionState" AS ENUM ('CONNECTED', 'DISCONNECTED', 'CONNECTING', 'CONNECTION_ISSUE');

-- CreateEnum
CREATE TYPE "BroadcastStatus" AS ENUM ('RUNNING', 'PAUSED', 'STOPPED', 'COMPLETED');

-- CreateEnum
CREATE TYPE "RecipientStatus" AS ENUM ('PENDING', 'SUBMITTED', 'FAILED', 'SKIPPED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "user_name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'USER',
    "status" "UserStatus" NOT NULL DEFAULT 'PENDING',
    "default_country_code" TEXT NOT NULL DEFAULT '+961',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WhatsappSessions" (
    "id" SERIAL NOT NULL,
    "user_id" UUID NOT NULL,
    "state" "ConnectionState" NOT NULL DEFAULT 'CONNECTING',
    "credentialsEncrypted" TEXT NOT NULL,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WhatsappSessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "contact_list" (
    "id" SERIAL NOT NULL,
    "user_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "contact_list_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "contacts" (
    "id" SERIAL NOT NULL,
    "list_id" INTEGER NOT NULL,
    "phone_number" TEXT NOT NULL,
    "is_valid" BOOLEAN NOT NULL DEFAULT true,
    "custom_fields" JSONB NOT NULL,

    CONSTRAINT "contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "storage_path" TEXT NOT NULL,
    "attachment_type" TEXT NOT NULL,
    "original_name" TEXT NOT NULL,
    "size_bytes" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "broadcasts" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "list_id" INTEGER NOT NULL,
    "message_text" TEXT NOT NULL,
    "attachment_id" INTEGER,
    "attachment_type" TEXT NOT NULL,
    "status" "BroadcastStatus" NOT NULL,
    "pause_reason" TEXT,
    "started_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "broadcasts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "broadcast_recipients" (
    "id" SERIAL NOT NULL,
    "broadcast_id" INTEGER NOT NULL,
    "phone_number" TEXT NOT NULL,
    "custom_fields" JSONB NOT NULL,
    "status" "RecipientStatus" NOT NULL DEFAULT 'PENDING',
    "error_category" TEXT,
    "failure_reason" TEXT,
    "processed_at" TIMESTAMPTZ,

    CONSTRAINT "broadcast_recipients_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_user_name_idx" ON "User"("user_name");

-- CreateIndex
CREATE INDEX "contacts_list_id_phone_number_idx" ON "contacts"("list_id", "phone_number");
