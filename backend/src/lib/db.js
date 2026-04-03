import dns from "node:dns/promises";
import mongoose from "mongoose";

// Set DNS servers for the entire process before connecting
dns.setServers(["1.1.1.1", "8.8.8.8"]);

export const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI);
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.log("MongoDB Connection error:", error);
  }
};
