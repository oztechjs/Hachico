import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { initializeApp } from "firebase-admin/app";
import axios from "axios";

// Firebase Admin初期化
try {
  initializeApp();
} catch (error) {
  // 既に初期化されている場合は無視
}

const db = getFirestore();
const openAiKey = defineSecret("OPENAI_API_KEY");

// 利用制限設定
const DAILY_LIMIT = 30; // 1日あたりの無料利用回数（30回に変更）
const PREMIUM_DAILY_LIMIT = 150; // プレミアムユーザーの1日あたり利用回数（150回に変更）

interface UserUsage {
  userId: string;
  dailyCount: number;
  lastResetDate: string;
  isPremium: boolean;
  totalUsage: number;
}

/**
 * ユーザーの利用状況を取得
 * @param {string} userId - ユーザーID
 * @return {Promise<UserUsage>} ユーザーの利用状況
 */
async function getUserUsage(userId: string): Promise<UserUsage> {
  const userDoc = await db.collection("users").doc(userId).get();

  if (!userDoc.exists) {
    // 新規ユーザー
    const newUser: UserUsage = {
      userId,
      dailyCount: 0,
      lastResetDate: new Date().toDateString(),
      isPremium: false,
      totalUsage: 0,
    };
    await db.collection("users").doc(userId).set(newUser);
    return newUser;
  }

  const data = userDoc.data() as UserUsage;

  // 日付が変わったらカウントをリセット
  const today = new Date().toDateString();
  if (data.lastResetDate !== today) {
    data.dailyCount = 0;
    data.lastResetDate = today;
    await db.collection("users").doc(userId).update({
      dailyCount: 0,
      lastResetDate: today,
    });
  }

  return data;
}

/**
 * 利用制限チェック
 * @param {string} userId - ユーザーID
 * @return {Promise<{allowed: boolean; message?: string}>} 利用可否とメッセージ
 */
async function checkUsageLimit(
  userId: string
): Promise<{ allowed: boolean; message?: string }> {
  const usage = await getUserUsage(userId);
  const limit = usage.isPremium ? PREMIUM_DAILY_LIMIT : DAILY_LIMIT;

  if (usage.dailyCount >= limit) {
    return {
      allowed: false,
      message: usage.isPremium
        ? `本日の利用上限（${PREMIUM_DAILY_LIMIT}回）に達しました。明日までお待ちください。`
        : `本日の無料利用上限（${DAILY_LIMIT}回）に達しました。プレミアムプランにアップグレードしてください。`,
    };
  }

  return { allowed: true };
}

/**
 * 利用回数を更新
 * @param {string} userId - ユーザーID
 */
async function incrementUsage(userId: string) {
  const userRef = db.collection("users").doc(userId);
  await userRef.update({
    dailyCount: FieldValue.increment(1),
    totalUsage: FieldValue.increment(1),
  });
}

export const chatWithOpenAI = onRequest(
  { secrets: [openAiKey] },
  async (req, res) => {
    const { systemPrompt, userMessage, userId } = req.body;

    if (!systemPrompt || !userMessage) {
      res.status(400).send("Missing systemPrompt or userMessage");
      return;
    }

    // ユーザーIDが提供されていない場合は一時的なIDを生成
    const currentUserId = userId || `temp_${Date.now()}`;

    // 利用制限チェック
    const usageCheck = await checkUsageLimit(currentUserId);
    if (!usageCheck.allowed) {
      res.status(429).send({
        error: "Usage limit exceeded",
        message: usageCheck.message,
      });
      return;
    }

    try {
      const response = await axios.post(
        "https://api.openai.com/v1/chat/completions",
        {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userMessage },
          ],
          temperature: 0.7,
          max_tokens: 150,
        },
        {
          headers: {
            Authorization: `Bearer ${openAiKey.value()}`,
            "Content-Type": "application/json",
          },
        }
      );

      // 利用回数を更新
      await incrementUsage(currentUserId);

      res.status(200).send({
        reply: response.data.choices[0].message.content,
        usage: {
          dailyCount: (await getUserUsage(currentUserId)).dailyCount,
          isPremium: (await getUserUsage(currentUserId)).isPremium,
        },
      });
    } catch (err: any) {
      try {
        console.error("OpenAI API error (stringified):", JSON.stringify(err));
        if (err.response) {
          console.error(
            "OpenAI API error (response):",
            JSON.stringify(err.response)
          );
        }
        if (err.response && err.response.data) {
          console.error(
            "OpenAI API error (response.data):",
            JSON.stringify(err.response.data)
          );
        }
        if (err.message) {
          console.error("OpenAI API error (message):", err.message);
        }
      } catch (e) {
        console.error("OpenAI API error (raw):", err);
      }
      res.status(500).send("Failed to call OpenAI API");
    }
  }
);

// ユーザー情報取得API
export const getUserInfo = onRequest(async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    res.status(400).send({ error: "Missing userId" });
    return;
  }

  try {
    const usage = await getUserUsage(userId as string);
    const limit = usage.isPremium ? PREMIUM_DAILY_LIMIT : DAILY_LIMIT;

    res.status(200).send({
      userId: usage.userId,
      dailyCount: usage.dailyCount,
      dailyLimit: limit,
      isPremium: usage.isPremium,
      totalUsage: usage.totalUsage,
      remainingToday: limit - usage.dailyCount,
    });
  } catch (error) {
    res.status(500).send({ error: "Failed to get user info" });
  }
});

// プレミアムアップグレードAPI
export const upgradeToPremium = onRequest(async (req, res) => {
  const { userId } = req.body;

  if (!userId) {
    res.status(400).send({ error: "Missing userId" });
    return;
  }

  try {
    await db.collection("users").doc(userId).update({
      isPremium: true,
    });

    res.status(200).send({
      message: "Successfully upgraded to premium",
      isPremium: true,
    });
  } catch (error) {
    res.status(500).send({ error: "Failed to upgrade to premium" });
  }
});
