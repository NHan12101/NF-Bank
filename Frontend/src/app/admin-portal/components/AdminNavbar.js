'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { getUser, clearSession, apiFetch } from '../../api';

export default function AdminNavbar() {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUserState] = useState(null);

  useEffect(() => {
    const u = getUser();
    if (!u) {
      router.push('/admin-portal/login');
    } else if (u.role !== 'admin' && u.role !== 'super_admin') {
      router.push('/dashboard'); // Kick regular users to user dashboard
    } else {
      setUserState(u);
    }
  }, [router]);

  const handleLogout = async () => {
    try {
      await apiFetch('/auth/logout', { method: 'POST' });
    } catch (e) {
      console.error('Logout error:', e);
    }
    clearSession();
    router.push('/admin-portal/login');
  };

  if (!user) return null;

  return (
    <header className="navbar" id="admin-navbar">
      <Link href="/admin-portal/dashboard" className="logo" id="admin-nav-logo" style={{ color: 'var(--secondary)' }}>
        NF-Bank Portal Quản Trị
      </Link>
      <nav className="nav-links" id="admin-nav-menu">
        <Link 
          href="/admin-portal/dashboard" 
          className={pathname === '/admin-portal/dashboard' ? 'active' : ''}
          id="admin-nav-link-dashboard"
        >
          Bảng điều khiển
        </Link>
      </nav>
      <div className="nav-user" id="admin-nav-user-section">
        <span className="nav-user-email" id="admin-nav-user-email" style={{ marginRight: '16px' }}>
          <span style={{
            fontSize: '0.75rem',
            padding: '2px 6px',
            borderRadius: '4px',
            background: user.role === 'super_admin' ? 'rgba(217, 70, 239, 0.2)' : 'rgba(6, 182, 212, 0.2)',
            color: user.role === 'super_admin' ? 'var(--accent)' : 'var(--secondary)',
            fontWeight: 'bold',
            marginRight: '8px'
          }}>
            {user.role === 'super_admin' ? 'SUPER ADMIN' : 'ADMIN'}
          </span>
          {user.full_name || user.email}
        </span>
        <button 
          onClick={handleLogout} 
          className="btn btn-secondary" 
          style={{ padding: '8px 16px', fontSize: '0.85rem', borderRadius: '8px', width: 'auto' }}
          id="admin-logout-btn"
        >
          Đăng xuất
        </button>
      </div>
    </header>
  );
}
