import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient, Prisma } from "../generated/prisma/client";
import type { BroadcastStatus, ConnectionState, RecipientStatus, UserRole, UserStatus } from "../generated/prisma/enums";

const prisma = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL })
});

async function main() {
    const accounts: {
        name: string; role: UserRole; status: UserStatus;
        country: string; session?: ConnectionState;
    }[] = [
            { name: "Jawad Admin", role: "ADMIN", status: "APPROVED", country: "+961", session: "CONNECTED" },
            { name: "Maya Haddad", role: "USER", status: "APPROVED", country: "+961", session: "CONNECTED" },
            { name: "Omar Pending", role: "USER", status: "PENDING", country: "+961" },
            { name: "Nour Rejected", role: "USER", status: "REJECTED", country: "+961", session: "DISCONNECTED" },
            { name: "Rami Blocked", role: "USER", status: "BLOCKED", country: "+961", session: "CONNECTION_ISSUE" },
            { name: "Sara Mansour", role: "USER", status: "APPROVED", country: "+44", session: "CONNECTING" },
            { name: "Karim Saleh", role: "USER", status: "APPROVED", country: "+1", session: "DISCONNECTED" },
            { name: "Lina Admin", role: "ADMIN", status: "APPROVED", country: "+961" },
        ];
    // Stable fixture IDs let reruns preserve unrelated application users.
    const userIds = accounts.map((_, index) => `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`);
    const now = Date.now();
    const daysAgo = (days: number) => new Date(now - days * 86_400_000);

    const summary = await prisma.$transaction(async (tx) => {
        // Broadcast.list has NoAction: remove broadcasts before cascading lists.
        // A failure rolls back cleanup and inserts together.
        await tx.broadcast.deleteMany({ where: { userId: { in: userIds } } });
        await tx.user.deleteMany({ where: { id: { in: userIds } } });
        for (const [index, account] of accounts.entries()) {
            await tx.user.create({
                data: {
                    id: userIds[index], email: `seed-${index + 1}@example.test`,
                    userName: account.name, phone: `202555${String(100 + index).padStart(4, "0")}`,
                    role: account.role, status: account.status, defaultCountryCode: account.country,
                    // No authentication/hash contract exists yet; deliberately unusable.
                    passwordHash: "SEED_ONLY_INVALID_PASSWORD_HASH", createdAt: daysAgo(60 - index * 5),
                    ...(account.session ? {
                        whatsappSession: {
                            create: {
                                state: account.session,
                                // UI fixtures only: never use fake credentials for real connections.
                                credentialsEncrypted: null, updatedAt: daysAgo(0.01 * (index + 1)),
                            }
                        }
                    } : {}),
                },
            });
        }

        const names = ["Maya", "Omar", "Nour", "Rami", "Sara", "Karim", "Lina", "Jad"];
        const contactData: Prisma.ContactCreateManyListInput[] = Array.from({ length: 32 }, (_, index) => ({
            phoneNumber: `+1202555${String(100 + index).padStart(4, "0")}`, isValid: true,
            customFields: { name: `${names[index % names.length]} ${index + 1}`, order: `DEMO-${1000 + index}`, city: index % 2 ? "Tripoli" : "Beirut" },
        }));
        contactData.push(
            { phoneNumber: "invalid-phone", isValid: false, customFields: { name: "Invalid import" } },
            { phoneNumber: "+12025550198", customFields: Prisma.DbNull },
            { phoneNumber: "+12025550199", customFields: {} },
            { phoneNumber: "+12025550197", customFields: { name: "ليلى حداد 🌿", city: "بيروت", order: "DEMO-AR" } },
        );
        const customers = await tx.contactList.create({
            data: { userId: userIds[1], name: "Customers", description: "Mixed CSV import: invalid numbers, missing fields, and Arabic text.", createdAt: daysAgo(30), contacts: { createMany: { data: contactData } } },
            include: { contacts: { orderBy: { id: "asc" } } },
        });
        const vip = await tx.contactList.create({
            data: { userId: userIds[1], name: "VIP", description: "Same phone in another list.", createdAt: daysAgo(20), contacts: { create: { phoneNumber: customers.contacts[0].phoneNumber, customFields: { name: "Maya VIP", discount: "20%" } } } },
            include: { contacts: true },
        });
        await tx.contactList.create({ data: { userId: userIds[1], name: "Empty import", description: null } });
        const ownerLists = [];
        // Repeated list names and phones across owners exercise tenant isolation.
        for (const userId of [userIds[0], userIds[4], userIds[5], userIds[6]]) {
            ownerLists.push(await tx.contactList.create({
                data: { userId, name: "Customers", description: null, createdAt: daysAgo(10), contacts: { create: { phoneNumber: "+12025550100", customFields: { name: "Demo customer" } } } },
                include: { contacts: true },
            }));
        }

        const attachments = [];
        for (const file of [
            { originalName: "summer-offer.jpg", attachmentType: "image/jpeg", sizeBytes: 245_760n },
            { originalName: "price-list.pdf", attachmentType: "application/pdf", sizeBytes: 1_048_576n },
            { originalName: "product-demo.mp4", attachmentType: "video/mp4", sizeBytes: 8_388_608n },
            { originalName: "welcome.ogg", attachmentType: "audio/ogg", sizeBytes: 65_536n },
            { originalName: "unused-draft.pdf", attachmentType: "application/pdf", sizeBytes: 4096n },
        ]) {
            // Metadata only: no files are uploaded by this seed.
            attachments.push(await tx.attachment.create({
                data: {
                    ...file, userId: userIds[1], storagePath: `seed/${userIds[1]}/${file.originalName}`, createdAt: daysAgo(15),
                }
            }));
        }

        type Scenario = {
            list: typeof customers; status: BroadcastStatus; days: number; message: string;
            attachment?: (typeof attachments)[number]; pauseReason?: string;
            outcomes: RecipientStatus[]; failure?: { category: string; reason: string };
        };
        const scenarios: Scenario[] = [
            { list: customers, status: "RUNNING", days: 0.01, message: "Hello {{name}}, order {{order}} is ready.", outcomes: ["SUBMITTED", "SUBMITTED", "PENDING", "PENDING"] },
            { list: vip, status: "RUNNING", days: 0.001, message: "Hello {{name}}, save {{discount}}!", attachment: attachments[0], outcomes: ["PENDING"] },
            { list: customers, status: "PAUSED", days: 0.1, message: "Hi {{name}}, see our latest offers.", attachment: attachments[0], pauseReason: "Paused by user", outcomes: ["SUBMITTED", "PENDING"] },
            { list: customers, status: "PAUSED", days: 0.2, message: "Hello {{name}}, here is our price list.", attachment: attachments[1], pauseReason: "WhatsApp connection lost", outcomes: ["SUBMITTED", "FAILED", "PENDING"], failure: { category: "CONNECTION", reason: "Connection lost before submission." } },
            { list: customers, status: "PAUSED", days: 0.3, message: "Service update for {{name}}.", pauseReason: "Rate limit reached; waiting to resume", outcomes: ["FAILED", "PENDING"], failure: { category: "RATE_LIMIT", reason: "Submission rate limit reached." } },
            { list: customers, status: "STOPPED", days: 1, message: "Hi {{name}}, watch our product demo.", attachment: attachments[2], outcomes: ["SUBMITTED", "FAILED", "SKIPPED"], failure: { category: "TIMEOUT", reason: "Submission timed out." } },
            { list: customers, status: "COMPLETED", days: 2, message: "Hello {{name}}, order {{order}} is confirmed.", attachment: attachments[1], outcomes: ["SUBMITTED", "FAILED", "SKIPPED", "SUBMITTED"], failure: { category: "NOT_ON_WHATSAPP", reason: "Phone number is not registered on WhatsApp." } },
            { list: vip, status: "COMPLETED", days: 4, message: "Thanks for being a VIP, {{name}}!", outcomes: ["SUBMITTED"] },
            { list: vip, status: "COMPLETED", days: 7, message: "Your welcome message, {{name}}.", attachment: attachments[3], outcomes: ["FAILED"], failure: { category: "MEDIA_UPLOAD", reason: "Audio upload failed before submission." } },
            { list: ownerLists[0], status: "COMPLETED", days: 10, message: "Admin service announcement.", outcomes: ["SUBMITTED"] },
            { list: ownerLists[1], status: "STOPPED", days: 5, message: "Account review announcement.", outcomes: ["SKIPPED"] },
            { list: ownerLists[2], status: "PAUSED", days: 0.05, message: "Hello {{name}}, waiting for pairing.", pauseReason: "Waiting for WhatsApp pairing", outcomes: ["PENDING"] },
            { list: ownerLists[3], status: "PAUSED", days: 0.1, message: "Hello {{name}}, reconnect to continue.", pauseReason: "WhatsApp disconnected", outcomes: ["PENDING"] },
        ];
        let recipientCount = 0;
        for (const scenario of scenarios) {
            const startedAt = daysAgo(scenario.days);
            const terminal = scenario.status === "COMPLETED" || scenario.status === "STOPPED";
            const recipients = scenario.list.contacts.map((contact, index) => {
                const status: RecipientStatus = contact.isValid ? scenario.outcomes[index % scenario.outcomes.length] : "SKIPPED";
                return {
                    phoneNumber: contact.phoneNumber,
                    customFields: contact.customFields === null ? Prisma.DbNull : contact.customFields as Prisma.InputJsonValue,
                    status,
                    processedAt: status === "PENDING" ? null : new Date(startedAt.getTime() + (index + 1) * 1000),
                    errorCategory: status === "FAILED" ? scenario.failure?.category ?? "SUBMISSION" : status === "SKIPPED" ? (contact.isValid ? "CANCELLED" : "INVALID_PHONE") : null,
                    failureReason: status === "FAILED" ? scenario.failure?.reason ?? "Message submission failed." : status === "SKIPPED" ? (contact.isValid ? "Recipient skipped by operator." : "Invalid phone number from import.") : null,
                };
            });
            await tx.broadcast.create({
                data: {
                    userId: scenario.list.userId, listId: scenario.list.id, messageText: scenario.message,
                    status: scenario.status, attachmentId: scenario.attachment?.id ?? null,
                    attachmentType: scenario.attachment?.attachmentType ?? null, pauseReason: scenario.pauseReason ?? null,
                    startedAt, endedAt: terminal ? new Date(startedAt.getTime() + (recipients.length + 1) * 1000) : null,
                    recipients: { createMany: { data: recipients } },
                }
            });
            recipientCount += recipients.length;
        }
        // Snapshots retain original values after a contact is edited or deleted.
        await tx.contact.update({ where: { id: customers.contacts[0].id }, data: { customFields: { name: "Maya Updated", order: "DEMO-NEW" } } });
        await tx.contact.delete({ where: { id: customers.contacts[1].id } });
        return {
            users: accounts.length, sessions: accounts.filter((account) => account.session).length,
            lists: 7, contacts: contactData.length + 4, attachments: attachments.length,
            broadcasts: scenarios.length, recipients: recipientCount,
        };
    }, { timeout: 30_000 });
    console.log("Seed fixtures created:", summary);
}

main().then(() => {
    console.log("Seeding completed successfully");
}).catch((e: unknown) => {
    console.error(e);
    process.exitCode = 1;
}).finally(async () => {
    await prisma.$disconnect();
})
