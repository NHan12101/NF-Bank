'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, setAccessToken, setUser, getAccessToken, getUser } from '../../api';

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    // Redirect if already logged in as admin
    const token = getAccessToken();
    const u = getUser();
    if (token && u && (u.role === 'admin' || u.role === 'super_admin')) {
      router.push('/admin-portal/dashboard');
    }
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await apiFetch('/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          email: email.trim(),
          password: password,
          totp_code: totpCode.trim()
        })
      });

      const data = await res.json();

      if (res.ok && data.success) {
        const authData = data.data;
        if (authData.access_token) {
          setAccessToken(authData.access_token);
          setUser(authData.user);
          router.push('/admin-portal/dashboard');
        } else {
          setError('Phản hồi từ máy chủ không hợp lệ.');
        }
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
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      padding: '20px',
      background: 'var(--bg-gradient)'
    }}>
      <div className="glass-container" style={{ maxWidth: '450px' }}>
        <div style={{ textAlign: 'center', marginBottom: '32px' }}>
          <h1 style={{ fontSize: '1.8rem', color: '#fff', marginBottom: '8px' }}>
            Portal Quản Trị
          </h1>
          <p className="subtitle" style={{ margin: 0 }}>
            Hệ thống ngân hàng số NF-Bank
          </p>
        </div>

        {error && (
          <div className="alert alert-danger" role="alert" style={{ marginBottom: '24px' }}>
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="admin-email">Tài khoản / Email</label>
            <input
              type="text"
              id="admin-email"
              placeholder="Nhập tài khoản hoặc email admin"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              autoComplete="username"
            />
          </div>

          <div className="form-group">
            <label htmlFor="admin-password">Mật khẩu</label>
            <input
              type="password"
              id="admin-password"
              placeholder="Nhập mật khẩu"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              autoComplete="current-password"
            />
          </div>

          <div className="form-group" style={{ marginBottom: '30px' }}>
            <label htmlFor="admin-totp">Mã xác thực Google Authenticator (TOTP)</label>
            <input
              type="text"
              id="admin-totp"
              placeholder="Nhập mã 6 chữ số"
              maxLength={6}
              pattern="\d{6}"
              value={totpCode}
              onChange={(e) => setTotpCode(e.target.value.replace(/\D/g, ''))}
              required
              disabled={loading}
              inputMode="numeric"
              style={{
                letterSpacing: '0.25em',
                textAlign: 'center',
                fontSize: '1.25rem',
                fontWeight: 'bold'
              }}
            />
            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px', textAlign: 'center' }}>
              Mã bảo mật gồm 6 số tự động cập nhật mỗi 30 giây trong ứng dụng của bạn.
            </span>
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading}
            style={{
              padding: '14px',
              fontSize: '1rem',
              fontWeight: 'bold',
              borderRadius: '12px',
              background: 'linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%)'
            }}
          >
            {loading ? 'Đang xác thực...' : 'Đăng nhập vào hệ thống'}
          </button>
        </form>
      </div>
    </div>
  );
}
