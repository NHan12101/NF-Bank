'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { getAccessToken, apiFetch } from '../api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // If already logged in, redirect to dashboard
    if (getAccessToken()) {
      router.push('/dashboard');
    }
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await apiFetch('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        // Store email and phone temporarily for OTP screen
        sessionStorage.setItem('otp_email', email);
        if (data.data && data.data.phone) {
          sessionStorage.setItem('otp_phone', data.data.phone);
        }
        router.push('/login/otp');
      } else {
        setError(data.message || 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      display: 'flex',
      flex: 1,
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      padding: '20px'
    }}>
      <div className="glass-container" id="login-container">
        <h1 id="login-title">NF-Bank</h1>
        <p className="subtitle" id="login-subtitle">Đăng nhập vào tài khoản của bạn</p>

        {error && (
          <div className="alert alert-danger" id="login-error-alert" role="alert">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} id="login-form">
          <div className="form-group">
            <label htmlFor="email-input">Email hoặc Số điện thoại</label>
            <input
              id="email-input"
              type="text"
              placeholder="nhanvien@nfbank.com hoặc +84..."
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              autoComplete="username"
            />
          </div>

          <div className="form-group">
            <label htmlFor="password-input">Mật khẩu</label>
            <input
              id="password-input"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              autoComplete="current-password"
            />
          </div>

          <button
            id="login-submit-btn"
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Đang xử lý...' : 'Đăng nhập'}
          </button>
        </form>

        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem' }} id="login-links">
          <Link href="/forgot-password" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }} id="forgot-password-link">
            Quên mật khẩu?
          </Link>
          <Link href="/register" style={{ color: 'var(--primary)', textDecoration: 'none', fontWeight: '600' }} id="register-link">
            Đăng ký ngay
          </Link>
        </div>
      </div>
    </div>
  );
}
