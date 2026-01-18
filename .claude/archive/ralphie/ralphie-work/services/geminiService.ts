
import { GoogleGenAI, GenerateContentResponse } from "@google/genai";

const getAI = () => new GoogleGenAI({ apiKey: process.env.API_KEY || '' });

export const analyzeDesign = async (variantName: string, concept: string): Promise<string> => {
  try {
    const ai = getAI();
    const response: GenerateContentResponse = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `You are a world-class UI/UX design critic. Analyze this app icon concept:
      
      Name: ${variantName}
      Description: ${concept}
      
      Provide a concise 2-sentence critique focusing on its suitability for watchOS. Keep it encouraging but professional.`,
    });
    return response.text || "No feedback available at this time.";
  } catch (error) {
    console.error("Gemini API Error:", error);
    return "Error: Could not retrieve design analysis. Please check your connection.";
  }
};
