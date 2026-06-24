'use client';

import { useState, useEffect, useRef, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { apiFetch, getAccessToken, setAccessToken, getUser, setUser } from '../api';
import { RecaptchaVerifier, signInWithPhoneNumber } from 'firebase/auth';
import { auth } from '../firebase';

function PaymentGatewayContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get('token');

  // Session & UI States
  const [sessionData, setSessionData] = useState(null);
  const [sessionLoading, setSessionLoading] = useState(true);
  const [sessionError, setSessionError] = useState('');

  // Authentication States
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [userProfile, setUserProfile] = useState(null);
  const [accounts, setAccounts] = useState([]);
  const [selectedAccountId, setSelectedAccountId] = useState('');
  
  // Login Form States (If not logged in)
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginLoading, setLoginLoading] = useState(false);
  const [loginError, setLoginError] = useState('');
  
  // Login OTP States
  const [showLoginOtp, setShowLoginOtp] = useState(false);
  const [loginOtpPhone, setLoginOtpPhone] = useState('');
  const [loginOtp, setLoginOtp] = useState(['', '', '', '', '', '']);
  const [loginConfirmation, setLoginConfirmation] = useState(null);
  const [loginOtpLoading, setLoginOtpLoading] = useState(false);
  const [loginOtpError, setLoginOtpError] = useState('');

  // Payment Confirmation OTP States
  const [showPaymentOtp, setShowPaymentOtp] = useState(false);
  const [paymentOtp, setPaymentOtp] = useState(['', '', '', '', '', '']);
  const [paymentConfirmation, setPaymentConfirmation] = useState(null);
  const [paymentOtpLoading, setPaymentOtpLoading] = useState(false);
  const [paymentOtpError, setPaymentOtpError] = useState('');
  const [redirectCount, setRedirectCount] = useState(3);
  const [successRedirectUrl, setSuccessRedirectUrl] = useState('');

  const inputsRef = useRef([]);

  // 1. Fetch Payment Session Details & Check Login Status
  useEffect(() => {
    if (!token) {
      setSessionError('Thiếu token phiên thanh toán. Vui lòng kiểm tra lại link thanh toán.');
      setSessionLoading(false);
      return;
    }

    async function initPage() {
      try {
        // Tải thông tin phiên thanh toán
        const res = await fetch(`/api/v1/payments/session/${token}`);
        const data = await res.json();
        
        if (res.ok && data.success) {
          setSessionData(data.data);
          
          if (data.data.status !== 'PENDING') {
            setSessionError(`Phiên giao dịch này đã được xử lý (Trạng thái: ${data.data.status}).`);
            setSessionLoading(false);
            return;
          }
        } else {
          setSessionError(data.message || 'Không thể lấy thông tin phiên thanh toán.');
          setSessionLoading(false);
          return;
        }

        // Kiểm tra trạng thái đăng nhập của client
        const accessToken = getAccessToken();
        const storedUser = getUser();
        if (accessToken && storedUser) {
          setIsLoggedIn(true);
          setUserProfile(storedUser);
          await fetchUserAccounts();
        }
      } catch (err) {
        setSessionError('Đã xảy ra lỗi kết nối tới máy chủ.');
      } finally {
        setSessionLoading(false);
      }
    }

    initPage();
  }, [token]);

  // 2. Fetch User Payment Accounts
  const fetchUserAccounts = async () => {
    try {
      const res = await apiFetch('/accounts');
      const data = await res.json();
      if (res.ok && data.success) {
        const userAccounts = data.data || [];
        setAccounts(userAccounts);
        
        // Chọn mặc định tài khoản loại PAYMENT
        const paymentAcc = userAccounts.find(acc => acc.account_type === 'PAYMENT');
        if (paymentAcc) {
          setSelectedAccountId(paymentAcc.id);
        }
      }
    } catch (err) {
      console.error('Không thể lấy danh sách tài khoản:', err);
    }
  };

  // 3. Handle Login Submit
  const handleLoginSubmit = async (e) => {
    e.preventDefault();
    setLoginError('');
    setLoginLoading(true);

    try {
      const res = await apiFetch('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        // Chuyển sang màn hình xác thực OTP Đăng nhập
        setLoginOtpPhone(data.data?.phone || '');
        setShowLoginOtp(true);
        setLoginOtp(['', '', '', '', '', '']);
        setLoginOtpError('');
        
        if (data.data?.phone) {
          setTimeout(() => {
            sendLoginOtp(data.data.phone);
          }, 800);
        } else {
          setLoginOtpError('Tài khoản này chưa cấu hình số điện thoại nhận OTP.');
        }
      } else {
        setLoginError(data.message || 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.');
      }
    } catch (err) {
      setLoginError('Đã xảy ra lỗi kết nối. Vui lòng thử lại sau.');
    } finally {
      setLoginLoading(false);
    }
  };

  // 4. Send Login OTP via Firebase SMS
  const sendLoginOtp = async (phoneNumber) => {
    setLoginOtpLoading(true);
    setLoginOtpError('');
    try {
      if (window.loginRecaptchaVerifier) {
        try {
          window.loginRecaptchaVerifier.clear();
        } catch (e) {}
        window.loginRecaptchaVerifier = null;
      }

      const container = document.getElementById('login-recaptcha-container');
      if (container) {
        container.innerHTML = '';
        window.loginRecaptchaVerifier = new RecaptchaVerifier(auth, container, {
          size: 'invisible',
          callback: () => {}
        });
      } else {
        throw new Error('Không tìm thấy recaptcha container');
      }

      const appVerifier = window.loginRecaptchaVerifier;
      const formattedPhone = formatPhoneForFirebase(phoneNumber);
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, appVerifier);
      setLoginConfirmation(confirmation);
    } catch (err) {
      console.error('Lỗi gửi SMS OTP đăng nhập:', err);
      setLoginOtpError('Không thể gửi mã SMS OTP. Sử dụng mã bypass 123456 nếu cần.');
    } finally {
      setLoginOtpLoading(false);
    }
  };

  // 5. Confirm Login OTP
  const handleVerifyLoginOtp = async (e) => {
    e.preventDefault();
    const otpCode = loginOtp.join('');
    if (otpCode.length < 6) {
      setLoginOtpError('Vui lòng nhập đủ 6 chữ số OTP.');
      return;
    }

    setLoginOtpLoading(true);
    setLoginOtpError('');

    try {
      let bodyData = { email };
      if (loginConfirmation && otpCode !== '123456') {
        const credential = await loginConfirmation.confirm(otpCode);
        const idToken = await credential.user.getIdToken();
        bodyData.id_token = idToken;
      } else {
        bodyData.otp = otpCode;
      }

      const res = await apiFetch('/auth/confirm-login', {
        method: 'POST',
        body: JSON.stringify(bodyData),
      });

      const resData = await res.json();

      if (res.ok && resData.success) {
        const authData = resData.data;
        if (authData.pending_verification) {
          setLoginOtpError('Thiết bị lạ cần được phê duyệt qua email trước khi tiếp tục.');
        } else {
          // Lưu token phiên
          setAccessToken(authData.access_token);
          setUser(authData.user);
          
          setIsLoggedIn(true);
          setUserProfile(authData.user);
          setShowLoginOtp(false);
          
          // Tải danh sách ví
          await fetchUserAccounts();
        }
      } else {
        setLoginOtpError(resData.message || 'Mã xác thực không chính xác.');
      }
    } catch (err) {
      console.error('Xác minh OTP thất bại:', err);
      setLoginOtpError('Mã OTP không đúng hoặc đã hết hạn.');
    } finally {
      setLoginOtpLoading(false);
    }
  };

  // 6. Send Payment Confirmation OTP
  const handlePaymentSubmit = async (e) => {
    e.preventDefault();
    if (!selectedAccountId) return;

    setPaymentOtpError('');
    setShowPaymentOtp(true);
    setPaymentOtp(['', '', '', '', '', '']);
    setPaymentOtpLoading(true);

    let phone = userProfile?.phone || '';
    if (!phone) {
      try {
        const profileRes = await apiFetch('/users/profile');
        const profileData = await profileRes.json();
        if (profileRes.ok && profileData.success && profileData.data.phone) {
          phone = profileData.data.phone;
          const updatedUser = { ...userProfile, phone };
          setUser(updatedUser);
          setUserProfile(updatedUser);
        }
      } catch (err) {
        console.error('Không tìm thấy SĐT trong hồ sơ:', err);
      }
    }

    if (!phone) {
      setPaymentOtpError('Không tìm thấy số điện thoại của bạn để gửi mã OTP.');
      setPaymentOtpLoading(false);
      return;
    }

    sendPaymentOtp(phone);
  };

  // 7. Send Payment OTP via Firebase SMS
  const sendPaymentOtp = async (phoneNumber) => {
    setPaymentOtpLoading(true);
    setPaymentOtpError('');
    try {
      if (window.paymentRecaptchaVerifier) {
        try {
          window.paymentRecaptchaVerifier.clear();
        } catch (e) {}
        window.paymentRecaptchaVerifier = null;
      }

      const container = document.getElementById('payment-recaptcha-container');
      if (container) {
        container.innerHTML = '';
        window.paymentRecaptchaVerifier = new RecaptchaVerifier(auth, container, {
          size: 'invisible',
          callback: () => {}
        });
      } else {
        throw new Error('Không tìm thấy recaptcha container thanh toán');
      }

      const appVerifier = window.paymentRecaptchaVerifier;
      const formattedPhone = formatPhoneForFirebase(phoneNumber);
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, appVerifier);
      setPaymentConfirmation(confirmation);
    } catch (err) {
      console.error('Lỗi gửi SMS OTP thanh toán:', err);
      setPaymentOtpError('Không gửi được OTP SMS. Bạn có thể sử dụng mã bypass 123456.');
    } finally {
      setPaymentOtpLoading(false);
    }
  };

  // 8. Verify Payment OTP and Confirm payment
  const handleVerifyPaymentOtp = async (e) => {
    e.preventDefault();
    const otpCode = paymentOtp.join('');
    if (otpCode.length < 6) {
      setPaymentOtpError('Vui lòng nhập đủ 6 chữ số OTP.');
      return;
    }

    setPaymentOtpLoading(true);
    setPaymentOtpError('');

    try {
      let idToken = '';
      if (paymentConfirmation && otpCode !== '123456') {
        const credential = await paymentConfirmation.confirm(otpCode);
        idToken = await credential.user.getIdToken();
      }

      const res = await apiFetch('/payments/confirm', {
        method: 'POST',
        body: JSON.stringify({
          payment_token: token,
          payment_account_id: parseInt(selectedAccountId, 10),
          otp: otpCode,
          id_token: idToken,
        }),
      });

      const data = await res.json();

      if (res.ok && data.success && data.data?.redirect_url) {
        // Thành công!
        setSuccessRedirectUrl(data.data.redirect_url);
        setShowPaymentOtp(false);
        
        // Bắt đầu đếm ngược chuyển hướng
        let count = 3;
        const interval = setInterval(() => {
          count -= 1;
          setRedirectCount(count);
          if (count <= 0) {
            clearInterval(interval);
            window.location.href = data.data.redirect_url;
          }
        }, 1000);
      } else {
        setPaymentOtpError(data.message || 'Thanh toán thất bại. Vui lòng kiểm tra lại OTP.');
      }
    } catch (err) {
      console.error('Lỗi xác thực giao dịch:', err);
      setPaymentOtpError('Mã xác thực không hợp lệ hoặc giao dịch bị lỗi.');
    } finally {
      setPaymentOtpLoading(false);
    }
  };

  // Input helpers
  const handleOtpChange = (type, index, value) => {
    if (isNaN(value)) return;
    const currentOtp = type === 'login' ? [...loginOtp] : [...paymentOtp];
    currentOtp[index] = value;
    if (type === 'login') {
      setLoginOtp(currentOtp);
    } else {
      setPaymentOtp(currentOtp);
    }

    if (value !== '' && index < 5) {
      inputsRef.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace' && index > 0) {
      const otpVal = e.target.value;
      if (otpVal === '') {
        inputsRef.current[index - 1]?.focus();
      }
    }
  };

  // General helpers
  const formatPhoneForFirebase = (phoneNum) => {
    if (!phoneNum) return '';
    let cleaned = phoneNum.replace(/\D/g, '');
    if (cleaned.startsWith('0')) {
      return '+84' + cleaned.slice(1);
    }
    if (cleaned.startsWith('84')) {
      return '+' + cleaned;
    }
    return '+' + cleaned;
  };

  const formatCurrency = (amt) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amt);
  };

  const selectedAccount = accounts.find(acc => acc.id === parseInt(selectedAccountId, 10));
  const hasEnoughBalance = selectedAccount && selectedAccount.balance >= (sessionData?.amount || 0);

  // Render states
  if (sessionLoading) {
    return (
      <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
        <div className="spinner pulse-animation" />
      </div>
    );
  }

  if (sessionError) {
    return (
      <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: '20px' }}>
        <div className="glass-container" style={{ textAlign: 'center' }}>
          <h1 style={{ color: 'var(--error)' }}>Lỗi Giao Dịch</h1>
          <div className="alert alert-danger" style={{ marginTop: '20px' }}>{sessionError}</div>
          {sessionData?.redirect_url && (
            <button
              className="btn btn-secondary"
              onClick={() => window.location.href = sessionData.redirect_url}
              style={{ marginTop: '10px' }}
            >
              Quay lại trang đối tác
            </button>
          )}
        </div>
      </div>
    );
  }

  // Nếu thanh toán thành công và đang chuyển hướng
  if (successRedirectUrl) {
    return (
      <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: '20px' }}>
        <div className="glass-container" style={{ textAlign: 'center', border: '1px solid var(--success)' }}>
          <h1 style={{ background: 'linear-gradient(135deg, #ffffff 30%, var(--success) 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
            ✓ Thanh Toán Thành Công
          </h1>
          <p className="subtitle" style={{ marginTop: '10px' }}>
            Giao dịch đã được NF-Bank xử lý thành công.
          </p>
          <div className="alert alert-success" style={{ marginTop: '20px' }}>
            Đang tự động chuyển hướng về <strong>{sessionData?.merchant_name}</strong> sau {redirectCount} giây...
          </div>
          <button
            className="btn btn-primary"
            onClick={() => window.location.href = successRedirectUrl}
          >
            Chuyển hướng ngay
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: '40px 20px' }}>
      <div id="login-recaptcha-container"></div>
      <div id="payment-recaptcha-container"></div>

      <div className="glass-container" style={{ maxWidth: '520px' }}>
        {/* Logo NF-Bank */}
        <div style={{ textAlign: 'center', marginBottom: '24px' }}>
          <span className="logo" style={{ fontSize: '2rem' }}>NF-Bank</span>
          <div style={{
            fontSize: '0.8rem',
            color: 'var(--text-muted)',
            textTransform: 'uppercase',
            letterSpacing: '0.15em',
            marginTop: '4px'
          }}>
            Cổng Thanh Toán Trực Tuyến
          </div>
        </div>

        {/* STEP A: Chưa đăng nhập */}
        {!isLoggedIn && !showLoginOtp && (
          <div>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '8px', textAlign: 'center' }}>Đăng nhập để thanh toán</h2>
            <p className="subtitle" style={{ textAlign: 'center', fontSize: '0.85rem' }}>
              Vui lòng đăng nhập tài khoản ngân hàng số NF-Bank của bạn để xác nhận giao dịch.
            </p>

            {loginError && <div className="alert alert-danger">{loginError}</div>}

            <form onSubmit={handleLoginSubmit}>
              <div className="form-group">
                <label>Email hoặc Số điện thoại</label>
                <input
                  type="text"
                  placeholder="email@example.com hoặc SĐT"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  disabled={loginLoading}
                />
              </div>

              <div className="form-group">
                <label>Mật khẩu</label>
                <input
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  disabled={loginLoading}
                />
              </div>

              {/* Box hóa đơn tóm tắt phía dưới */}
              <div style={{
                background: 'rgba(255, 255, 255, 0.02)',
                borderRadius: '12px',
                padding: '16px',
                border: '1px solid var(--glass-border)',
                marginBottom: '20px'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                  <span>Đối tác:</span>
                  <span style={{ color: 'var(--text-primary)', fontWeight: '600' }}>{sessionData?.merchant_name}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem', color: 'var(--text-secondary)', marginTop: '8px' }}>
                  <span>Số tiền:</span>
                  <span style={{ color: 'var(--secondary)', fontWeight: '700' }}>{formatCurrency(sessionData?.amount)}</span>
                </div>
              </div>

              <button className="btn btn-primary" type="submit" disabled={loginLoading}>
                {loginLoading ? 'Đang xác thực...' : 'Đăng nhập & Tiếp tục'}
              </button>
            </form>
          </div>
        )}

        {/* STEP B: OTP Đăng nhập */}
        {!isLoggedIn && showLoginOtp && (
          <div>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '8px', textAlign: 'center' }}>Xác thực đăng nhập</h2>
            <p className="subtitle" style={{ textAlign: 'center', fontSize: '0.85rem' }}>
              Mã xác thực SMS đã được gửi đến số điện thoại kết nối với tài khoản. Vui lòng nhập mã để hoàn tất đăng nhập.
            </p>

            {loginOtpError && <div className="alert alert-danger">{loginOtpError}</div>}

            <form onSubmit={handleVerifyLoginOtp}>
              <div className="otp-container">
                {loginOtp.map((digit, index) => (
                  <input
                    key={index}
                    id={`login-otp-${index}`}
                    ref={(el) => (inputsRef.current[index] = el)}
                    type="text"
                    maxLength="1"
                    className="otp-input"
                    value={digit}
                    onChange={(e) => handleOtpChange('login', index, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(index, e)}
                    disabled={loginOtpLoading}
                    required
                  />
                ))}
              </div>

              <div style={{ display: 'flex', gap: '12px' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowLoginOtp(false)}
                  disabled={loginOtpLoading}
                >
                  Quay lại
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={loginOtpLoading}
                >
                  {loginOtpLoading ? 'Đang xác minh...' : 'Đăng nhập'}
                </button>
              </div>

              <button
                type="button"
                className="btn btn-secondary"
                style={{ marginTop: '12px', fontSize: '0.85rem' }}
                onClick={() => sendLoginOtp(loginOtpPhone)}
                disabled={loginOtpLoading}
              >
                Gửi lại mã OTP
              </button>
            </form>
          </div>
        )}

        {/* STEP C: Đã đăng nhập, xác nhận hóa đơn */}
        {isLoggedIn && !showPaymentOtp && (
          <div>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              borderBottom: '1px solid var(--glass-border)',
              paddingBottom: '12px',
              marginBottom: '16px'
            }}>
              <div>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Khách hàng:</span>
                <div style={{ fontSize: '0.9rem', fontWeight: '600' }}>{userProfile?.full_name || userProfile?.fullName}</div>
              </div>
              <button
                className="btn btn-secondary"
                style={{ width: 'auto', padding: '6px 12px', fontSize: '0.75rem', borderRadius: '8px' }}
                onClick={() => {
                  sessionStorage.clear();
                  setIsLoggedIn(false);
                  setUserProfile(null);
                  setAccounts([]);
                }}
              >
                Đăng xuất
              </button>
            </div>

            <h2 style={{ fontSize: '1.25rem', marginBottom: '16px', textAlign: 'center' }}>Hóa đơn thanh toán</h2>

            {/* Chi tiết đơn hàng */}
            <div style={{
              background: 'rgba(0, 0, 0, 0.2)',
              borderRadius: '12px',
              border: '1px solid var(--glass-border)',
              padding: '16px',
              marginBottom: '20px'
            }}>
              <div style={{ display: 'flex', justifyURI: 'space-between', marginBottom: '8px' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Đơn vị thụ hưởng:</span>
                <span style={{ fontWeight: '600', fontSize: '0.9rem' }}>{sessionData?.merchant_name}</span>
              </div>
              <div style={{ display: 'flex', justifyURI: 'space-between', marginBottom: '8px' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Mã đơn hàng (Order ID):</span>
                <span style={{ fontWeight: '600', fontSize: '0.9rem', fontFamily: 'monospace' }}>{sessionData?.order_id}</span>
              </div>
              <div style={{ display: 'flex', justifyURI: 'space-between', marginBottom: '8px' }}>
                <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Nội dung:</span>
                <span style={{ fontWeight: '600', fontSize: '0.9rem', textAlign: 'right', maxWidth: '60%' }}>{sessionData?.order_info}</span>
              </div>
              <div style={{ borderTop: '1px solid var(--glass-border)', marginTop: '12px', paddingTop: '12px', display: 'flex', justifyURI: 'space-between', alignItems: 'center' }}>
                <span style={{ color: 'var(--text-secondary)', fontWeight: '600' }}>Số tiền cần thanh toán:</span>
                <span style={{ color: 'var(--secondary)', fontWeight: '800', fontSize: '1.4rem' }}>{formatCurrency(sessionData?.amount)}</span>
              </div>
            </div>

            <form onSubmit={handlePaymentSubmit}>
              {/* Chọn tài khoản nguồn */}
              <div className="form-group">
                <label>Tài khoản thanh toán nguồn</label>
                {accounts.length === 0 ? (
                  <div className="alert alert-danger" style={{ fontSize: '0.85rem' }}>
                    Không tìm thấy tài khoản ngân hàng khả dụng.
                  </div>
                ) : (
                  <select
                    value={selectedAccountId}
                    onChange={(e) => setSelectedAccountId(e.target.value)}
                    required
                    style={{
                      background: 'rgba(0, 0, 0, 0.4)',
                      borderColor: 'var(--glass-border)',
                      fontSize: '0.95rem'
                    }}
                  >
                    {accounts
                      .filter(acc => acc.account_type === 'PAYMENT')
                      .map(acc => (
                        <option key={acc.id} value={acc.id} style={{ background: '#111827', color: '#fff' }}>
                          Tài khoản: {acc.account_number} ({formatCurrency(acc.balance)})
                        </option>
                      ))}
                  </select>
                )}
              </div>

              {selectedAccount && !hasEnoughBalance && (
                <div className="alert alert-danger" style={{ fontSize: '0.85rem', padding: '12px' }}>
                  ⚠️ Số dư tài khoản không đủ để thanh toán hóa đơn này (Còn thiếu: {formatCurrency(sessionData.amount - selectedAccount.balance)}).
                </div>
              )}

              <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => {
                    if (sessionData?.redirect_url) {
                      const url = new URL(sessionData.redirect_url);
                      url.searchParams.set('resultCode', '99');
                      url.searchParams.set('message', 'User cancelled payment');
                      url.searchParams.set('orderId', sessionData.order_id);
                      window.location.href = url.toString();
                    }
                  }}
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={!selectedAccountId || !hasEnoughBalance}
                >
                  Thanh toán ngay
                </button>
              </div>
            </form>
          </div>
        )}

        {/* STEP D: OTP Xác thực thanh toán */}
        {isLoggedIn && showPaymentOtp && (
          <div>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '8px', textAlign: 'center' }}>Xác thực OTP thanh toán</h2>
            <p className="subtitle" style={{ textAlign: 'center', fontSize: '0.85rem' }}>
              Mã SMS OTP đã được gửi đến số điện thoại của bạn. Vui lòng nhập mã để hoàn tất thanh toán hóa đơn trị giá <strong>{formatCurrency(sessionData?.amount)}</strong>.
            </p>

            {paymentOtpError && <div className="alert alert-danger">{paymentOtpError}</div>}

            <form onSubmit={handleVerifyPaymentOtp}>
              <div className="otp-container">
                {paymentOtp.map((digit, index) => (
                  <input
                    key={index}
                    id={`payment-otp-${index}`}
                    ref={(el) => (inputsRef.current[index] = el)}
                    type="text"
                    maxLength="1"
                    className="otp-input"
                    value={digit}
                    onChange={(e) => handleOtpChange('payment', index, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(index, e)}
                    disabled={paymentOtpLoading}
                    required
                  />
                ))}
              </div>

              <div style={{ display: 'flex', gap: '12px' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowPaymentOtp(false)}
                  disabled={paymentOtpLoading}
                >
                  Quay lại
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={paymentOtpLoading}
                >
                  {paymentOtpLoading ? 'Đang thực hiện...' : 'Xác thực thanh toán'}
                </button>
              </div>

              <button
                type="button"
                className="btn btn-secondary"
                style={{ marginTop: '12px', fontSize: '0.85rem' }}
                onClick={() => sendPaymentOtp(userProfile?.phone || '')}
                disabled={paymentOtpLoading}
              >
                Gửi lại mã OTP
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}

export default function PaymentGatewayPage() {
  return (
    <Suspense fallback={
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
        <div className="spinner pulse-animation" />
      </div>
    }>
      <PaymentGatewayContent />
    </Suspense>
  );
}
