'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiFetch, getAccessToken } from '../api';
import Navbar from '../components/Navbar';

export default function ProfilePage() {
  const router = useRouter();
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Form states
  const [address, setAddress] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [gender, setGender] = useState('Khác');
  const [dob, setDob] = useState('');

  const fetchProfile = async () => {
    setLoading(true);
    try {
      const res = await apiFetch('/users/me');
      const data = await res.json();

      if (res.ok && data.success) {
        const p = data.data;
        setProfile(p);
        setAddress(p.address || '');
        setAvatarUrl(p.avatar_url || '');
        setGender(p.gender || 'Khác');
        
        // Convert Go time (e.g. 1995-03-24T00:00:00Z) to yyyy-MM-dd
        if (p.date_of_birth) {
          setDob(p.date_of_birth.substring(0, 10));
        } else {
          setDob('');
        }
      } else {
        setError(data.message || 'Không thể lấy thông tin cá nhân.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const token = getAccessToken();
    if (!token) {
      router.push('/login');
    } else {
      fetchProfile();
    }
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setSubmitting(true);

    try {
      // Parse dob string to Go RFC3339 format
      let formattedDob = null;
      if (dob) {
        formattedDob = dob + 'T00:00:00Z';
      }

      const res = await apiFetch('/users/me', {
        method: 'PUT',
        body: JSON.stringify({
          address: address.trim(),
          avatar_url: avatarUrl.trim(),
          gender,
          date_of_birth: formattedDob,
        }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        setSuccess('Cập nhật thông tin cá nhân thành công!');
        fetchProfile(); // Reload profile
      } else {
        setError(data.message || 'Cập nhật thất bại. Vui lòng kiểm tra lại thông tin.');
      }
    } catch (err) {
      setError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <main style={{ padding: '40px 20px', maxWidth: '1200px', margin: '0 auto', width: '100%' }} id="profile-main">
        {loading ? (
          <div style={{ textAlign: 'center', padding: '40px' }} id="profile-loading">
            <div className="spinner pulse-animation" />
            <p style={{ color: 'var(--text-secondary)' }}>Đang tải thông tin hồ sơ...</p>
          </div>
        ) : error && !profile ? (
          <div className="alert alert-danger" role="alert" id="profile-error-container">
            {error}
          </div>
        ) : (
          <div className="dashboard-grid" style={{ gridTemplateColumns: '1fr' }} id="profile-content-grid">
            <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '30px' }}>
              {/* Profile Card Header */}
              <div className="dashboard-card" id="profile-header-card" style={{ display: 'flex', alignItems: 'center', gap: '24px', flexWrap: 'wrap' }}>
                <div style={{
                  width: '100px',
                  height: '100px',
                  borderRadius: '50%',
                  background: 'linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '2.5rem',
                  fontWeight: 'bold',
                  color: '#fff',
                  boxShadow: '0 4px 12px rgba(99, 102, 241, 0.3)',
                  overflow: 'hidden'
                }} id="profile-avatar-display">
                  {avatarUrl ? (
                    <img src={avatarUrl} alt="Avatar" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : (
                    profile.full_name?.charAt(0).toUpperCase() || 'U'
                  )}
                </div>
                <div>
                  <h2 style={{ marginBottom: '6px' }} id="profile-display-name">{profile.full_name}</h2>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', marginBottom: '4px' }}>
                    Vai trò: <span style={{ color: 'var(--secondary)', fontWeight: 'bold' }}>{profile.role?.toUpperCase()}</span>
                  </p>
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                    Trạng thái: {profile.is_verified ? (
                      <span style={{ color: 'var(--success)' }}>✓ Đã xác minh</span>
                    ) : (
                      <span style={{ color: 'var(--error)' }}>Chưa xác minh</span>
                    )}
                    {profile.is_locked && (
                      <span style={{ color: 'var(--error)', marginLeft: '12px' }}>🔒 Đang bị khóa</span>
                    )}
                  </p>
                </div>
              </div>

              {/* Form & details grid */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '30px' }} className="profile-details-section">
                {/* Profile Edit Card */}
                <div className="dashboard-card" id="profile-edit-card">
                  <h2 style={{ marginBottom: '20px' }}>Chỉnh sửa hồ sơ</h2>
                  
                  {error && (
                    <div className="alert alert-danger" role="alert" id="profile-edit-error">
                      {error}
                    </div>
                  )}

                  {success && (
                    <div className="alert alert-success" role="alert" id="profile-edit-success">
                      {success}
                    </div>
                  )}

                  <form onSubmit={handleSubmit} id="profile-form" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                    {/* Readonly Identity fields */}
                    <div className="form-group" style={{ gridColumn: 'span 2' }}>
                      <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 'bold' }}>Họ và tên</span>
                      <input type="text" value={profile.full_name || ''} disabled style={{ background: 'rgba(255,255,255,0.03)', color: 'var(--text-secondary)' }} />
                    </div>

                    <div className="form-group">
                      <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 'bold' }}>Địa chỉ Email</span>
                      <input type="text" value={profile.email || ''} disabled style={{ background: 'rgba(255,255,255,0.03)', color: 'var(--text-secondary)' }} />
                    </div>

                    <div className="form-group">
                      <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 'bold' }}>Số điện thoại</span>
                      <input type="text" value={profile.phone || ''} disabled style={{ background: 'rgba(255,255,255,0.03)', color: 'var(--text-secondary)' }} />
                    </div>

                    {/* Editable fields */}
                    <div className="form-group">
                      <label htmlFor="prof-gender">Giới tính</label>
                      <select
                        id="prof-gender"
                        value={gender}
                        onChange={(e) => setGender(e.target.value)}
                        disabled={submitting}
                        style={{ background: 'rgba(0,0,0,0.3)', border: '1px solid var(--glass-border)', color: '#fff', padding: '14px 16px', borderRadius: '12px' }}
                      >
                        <option value="Nam" style={{ background: '#0d0f1a' }}>Nam</option>
                        <option value="Nữ" style={{ background: '#0d0f1a' }}>Nữ</option>
                        <option value="Khác" style={{ background: '#0d0f1a' }}>Khác</option>
                      </select>
                    </div>

                    <div className="form-group">
                      <label htmlFor="prof-dob">Ngày sinh (Tuổi hiện tại: {profile.age || 0})</label>
                      <input
                        id="prof-dob"
                        type="date"
                        value={dob}
                        onChange={(e) => setDob(e.target.value)}
                        disabled={submitting}
                        style={{ colorScheme: 'dark' }}
                      />
                    </div>

                    <div className="form-group" style={{ gridColumn: 'span 2' }}>
                      <label htmlFor="prof-avatar">Đường dẫn ảnh đại diện (Avatar URL)</label>
                      <input
                        id="prof-avatar"
                        type="text"
                        placeholder="https://example.com/avatar.jpg"
                        value={avatarUrl}
                        onChange={(e) => setAvatarUrl(e.target.value)}
                        disabled={submitting}
                      />
                    </div>

                    <div className="form-group" style={{ gridColumn: 'span 2' }}>
                      <label htmlFor="prof-address">Địa chỉ thường trú</label>
                      <textarea
                        id="prof-address"
                        placeholder="123 Đường ABC, Quận XYZ, TP..."
                        value={address}
                        onChange={(e) => setAddress(e.target.value)}
                        disabled={submitting}
                        rows="3"
                        style={{ resize: 'none' }}
                      />
                    </div>

                    <div style={{ gridColumn: 'span 2', marginTop: '10px' }}>
                      <button
                        id="profile-save-btn"
                        type="submit"
                        className="btn btn-primary"
                        disabled={submitting}
                      >
                        {submitting ? 'Đang lưu...' : 'Lưu thay đổi'}
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </>
  );
}
