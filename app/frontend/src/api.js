import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "";
const baseURL = BACKEND_URL ? `${BACKEND_URL}/api` : "/api";

const api = axios.create({
  baseURL,
  timeout: 10_000,
});

export default api;
